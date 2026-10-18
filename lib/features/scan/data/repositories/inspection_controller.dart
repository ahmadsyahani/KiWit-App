import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/inspection_result_data.dart';
import '../models/saved_inspection.dart';
import 'inspection_local_storage.dart';

class InspectionSyncException implements Exception {
  const InspectionSyncException(this.message);
  final String message;
}

abstract interface class InspectionRemoteStorage {
  bool get canSync;
  Future<SavedInspection> push(SavedInspection record);
  Future<List<SavedInspection>> fetchAll();
  Future<String?> photoUrl(String path);
  void listen(void Function() onChange);
  void dispose();
}

class InspectionFeed {
  InspectionFeed({
    required List<SavedInspection> records,
    this.syncing = false,
    this.syncIssue,
  }) : records = List.unmodifiable(records);

  final List<SavedInspection> records;
  final bool syncing;
  final String? syncIssue;

  int get pendingCount => records.where((record) => !record.isSynced).length;
}

/// Disk commits are serialized; network requests stay outside that queue so
/// saving locally does not wait for a slow connection.
class InspectionController extends StateNotifier<AsyncValue<InspectionFeed>> {
  InspectionController({
    required this.ownerId,
    required this.local,
    this.remote,
  }) : super(const AsyncValue.loading()) {
    _initialization = _enqueue(() async {
      final records = await local.load();
      _requireOwner(records);
      _records = _sort(records);
      _emit();
    });
    unawaited(_start());
  }

  final String ownerId;
  final InspectionLocalStorage local;
  final InspectionRemoteStorage? remote;

  List<SavedInspection> _records = [];
  Future<void> _queue = Future.value();
  late final Future<void> _initialization;
  Future<void>? _refreshFuture;
  Timer? _retryTimer;
  Timer? _changeDebounce;
  bool _disposed = false;
  bool _syncing = false;
  bool _refreshAgain = false;
  String? _syncIssue;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _requireOwner(List<SavedInspection> records) {
    if (records.any((record) => record.ownerId != ownerId)) {
      throw const InspectionSyncException('Data inspeksi tidak sesuai akun.');
    }
  }

  Future<void> _start() async {
    try {
      await _initialization;
    } catch (error, stackTrace) {
      if (!_disposed) state = AsyncValue.error(error, stackTrace);
      return;
    }
    if (_disposed) return;
    try {
      remote?.listen(() {
        if (_disposed) return;
        _changeDebounce?.cancel();
        _changeDebounce = Timer(const Duration(milliseconds: 400), () {
          unawaited(refresh());
        });
      });
    } catch (_) {
      _syncIssue = 'Pembaruan otomatis belum terhubung. Coba sinkronkan lagi.';
    }
    _retryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(refresh());
    });
    await refresh();
  }

  List<SavedInspection> _sort(List<SavedInspection> records) {
    return [...records]..sort((a, b) {
      final byScan = b.data.scanTimestamp.compareTo(a.data.scanTimestamp);
      return byScan != 0 ? byScan : b.savedAt.compareTo(a.savedAt);
    });
  }

  void _emit() {
    if (_disposed) return;
    state = AsyncValue.data(InspectionFeed(
      records: _records,
      syncing: _syncing,
      syncIssue: _syncIssue,
    ));
  }

  Future<SavedInspection> save({
    required InspectionResultData data,
    required String notes,
    required String inspectorName,
    required String rayon,
  }) async {
    await _initialization;
    final result = await _enqueue(() async {
      if (_disposed) throw StateError('Sesi akun telah berubah.');
      final id = const Uuid().v4();
      final photo = await local.preservePhoto(id, data.imagePath);
      final record = SavedInspection(
        id: id,
        ownerId: ownerId,
        data: data.copyWith(imagePath: photo),
        savedAt: DateTime.now(),
        notes: notes,
        inspectorName: inspectorName,
        rayon: rayon,
      );
      final next = _sort([..._records, record]);
      await local.write(next);
      _records = next;
      _emit();
      return record;
    });
    unawaited(refresh());
    return result;
  }

  Future<void> refresh() {
    if (_disposed) return Future.value();
    final running = _refreshFuture;
    if (running != null) {
      _refreshAgain = true;
      return running;
    }
    return _refreshFuture = _refreshOnce();
  }

  Future<void> _refreshOnce() async {
    try {
      await _initialization;
      do {
        _refreshAgain = false;
        await _synchronize();
      } while (_refreshAgain && !_disposed);
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _synchronize() async {
    if (_disposed) return;
    final cloud = remote;
    if (cloud == null || !cloud.canSync) {
      _syncIssue = _records.any((record) => !record.isSynced)
          ? 'Masuk ke akun untuk menyinkronkan inspeksi.'
          : null;
      _emit();
      return;
    }
    _syncing = true;
    _emit();
    try {
      for (final pending in _records.where((record) => !record.isSynced).toList()) {
        if (_disposed) return;
        final synced = await cloud.push(pending);
        await _enqueue(() async {
          if (_disposed) return;
          _requireOwner([synced]);
          final next = _records.map((record) => record.id == synced.id ? synced : record).toList();
          await local.write(next);
          _records = next;
          _emit();
        });
      }
      final remoteRecords = await cloud.fetchAll();
      _requireOwner(remoteRecords);
      await _enqueue(() async {
        if (_disposed) return;
        // Re-read the latest local snapshot after the request; a new save may
        // have completed while cloud data was being fetched.
        final localById = {for (final record in _records) record.id: record};
        final merged = <String, SavedInspection>{};
        for (final record in remoteRecords) {
          merged[record.id] = record.copyWith(
            data: record.data.copyWith(
              imagePath: localById[record.id]?.data.imagePath ?? '',
            ),
            isSynced: true,
          );
        }
        for (final pending in _records.where((record) => !record.isSynced)) {
          merged[pending.id] = pending;
        }
        final next = _sort(merged.values.toList());
        await local.write(next);
        _records = next;
      });
      _syncIssue = null;
    } catch (error) {
      _syncIssue = error is InspectionSyncException
          ? error.message
          : 'Belum bisa terhubung ke penyimpanan cloud. Coba sinkronkan lagi.';
    } finally {
      _syncing = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _changeDebounce?.cancel();
    remote?.dispose();
    super.dispose();
  }
}
