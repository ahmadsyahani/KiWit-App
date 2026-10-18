import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/risk_badge.dart';
import '../../scan/data/repositories/inspection_controller.dart';
import '../../scan/presentation/providers/inspection_providers.dart';
import '../data/notification_entry.dart';
import '../data/notification_storage.dart';

class NotificationInbox {
  NotificationInbox({
    List<NotificationEntry> entries = const [],
    this.loading = false,
    this.storageIssue,
  }) : entries = List.unmodifiable(entries);
  final List<NotificationEntry> entries;
  final bool loading;
  final String? storageIssue;
  int get unreadCount => entries.where((entry) => !entry.isRead).length;
}

final notificationStorageProvider = Provider<NotificationStorage>((ref) =>
  FileNotificationStorage(ref.watch(currentUserIdProvider) ?? 'guest'));

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationInbox>((ref) {
  final controller = NotificationController(
    ownerId: ref.watch(currentUserIdProvider) ?? 'guest',
    storage: ref.watch(notificationStorageProvider),
  );
  ref.listen<AsyncValue<InspectionFeed>>(inspectionControllerProvider, (_, next) {
    final feed = next.valueOrNull;
    if (feed != null) unawaited(controller.receive(feed));
  }, fireImmediately: true);
  return controller;
});

class NotificationController extends StateNotifier<NotificationInbox> {
  NotificationController({
    required this.ownerId,
    required this.storage,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now, super(NotificationInbox(loading: true)) {
    _ready = _load();
  }

  final String ownerId;
  final NotificationStorage storage;
  final DateTime Function() _now;
  late final Future<void> _ready;
  Future<void> _queue = Future.value();
  bool _disposed = false;

  Future<void> _load() async {
    try {
      final entries = await storage.load();
      if (!_disposed) state = NotificationInbox(entries: _sorted(entries));
    } catch (_) {
      if (!_disposed) {
        state = NotificationInbox(storageIssue: 'Riwayat notifikasi belum dapat dibaca di perangkat ini.');
      }
    }
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) async {
      await _ready;
      if (!_disposed) await action();
    });
    _queue = next.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return next;
  }

  List<NotificationEntry> _sorted(Iterable<NotificationEntry> entries) =>
    entries.toList()..sort((a, b) {
      final byTime = b.createdAt.compareTo(a.createdAt);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });

  Future<void> _commit(List<NotificationEntry> entries) async {
    final sorted = _sorted(entries);
    final changed = jsonEncode(sorted.map((item) => item.toJson()).toList()) !=
        jsonEncode(state.entries.map((item) => item.toJson()).toList());
    if (!changed && state.storageIssue == null) return;
    state = NotificationInbox(entries: sorted, storageIssue: state.storageIssue);
    try {
      await storage.write(sorted);
      if (!_disposed) state = NotificationInbox(entries: sorted);
    } catch (_) {
      if (!_disposed) {
        state = NotificationInbox(entries: sorted,
          storageIssue: 'Status dibaca belum tersimpan di perangkat. Coba lagi.');
      }
    }
  }

  Future<void> receive(InspectionFeed feed) => _enqueue(() async {
    final records = feed.records.where((record) => record.ownerId == ownerId).toList();
    final existing = {for (final entry in state.entries) entry.id: entry};
    final next = <NotificationEntry>[];
    for (final record in records) {
      if (record.riskLevel != RiskLevel.tinggi && record.riskLevel != RiskLevel.kritis) {
        continue;
      }
      final level = record.riskLevel == RiskLevel.kritis ? 'kritis' : 'tinggi';
      final id = 'risk:${record.id}:$level';
      next.add(NotificationEntry(
        id: id, kind: NotificationKind.risk,
        title: 'Inspeksi berisiko $level',
        message: '${record.data.locationAddress.trim().isEmpty ? 'Lokasi belum dicatat' : record.data.locationAddress}. Perlu pemeriksaan lanjutan.',
        createdAt: existing[id]?.createdAt ?? record.savedAt,
        isRead: existing[id]?.isRead ?? false, recordId: record.id,
      ));
    }

    // Retain just ten resolved sync summaries; risk notices follow the live feed.
    next.addAll(state.entries.where((entry) => entry.kind == NotificationKind.syncComplete).take(10));
    final pending = records.where((record) => !record.isSynced).map((record) => record.id).toList()..sort();
    final previous = existing['sync:pending'];
    if (feed.syncing) {
      next.addAll(state.entries.where((entry) =>
        entry.kind == NotificationKind.syncPending || entry.kind == NotificationKind.syncIssue));
    } else if (pending.isNotEmpty) {
      if (feed.syncIssue != null || previous != null) {
        final additions = pending.any((id) => !(previous?.pendingIds.contains(id) ?? false));
        next.add(NotificationEntry(
          id: 'sync:pending', kind: NotificationKind.syncPending,
          title: '${pending.length} inspeksi belum tersinkron',
          message: 'Data tersimpan di HP ini. Buka untuk melihat daftar dan mencoba sinkronisasi.',
          createdAt: previous == null || additions ? _now() : previous.createdAt,
          isRead: !additions && (previous?.isRead ?? false), pendingIds: pending,
        ));
      }
    } else if (feed.syncIssue != null) {
      final issue = existing['sync:issue'];
      next.add(NotificationEntry(
        id: 'sync:issue', kind: NotificationKind.syncIssue,
        title: 'Sinkronisasi perlu dicoba lagi',
        message: feed.syncIssue!,
        createdAt: issue?.createdAt ?? _now(),
        isRead: issue?.message == feed.syncIssue && (issue?.isRead ?? false),
      ));
    } else if (previous != null && previous.pendingIds.isNotEmpty &&
        previous.pendingIds.every((id) =>
          records.any((record) => record.id == id && record.isSynced))) {
      final completedAt = _now();
      next.insert(0, NotificationEntry(
        id: 'sync:complete:${const Uuid().v4()}',
        kind: NotificationKind.syncComplete, title: 'Inspeksi berhasil tersinkron',
        message: 'Data yang sebelumnya tertunda sudah tersinkron ke akun ini.',
        createdAt: completedAt,
      ));
    }
    final summaries = next.where((entry) => entry.kind == NotificationKind.syncComplete)
        .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final retainedIds = summaries.take(10).map((entry) => entry.id).toSet();
    await _commit(next.where((entry) => entry.kind != NotificationKind.syncComplete ||
      retainedIds.contains(entry.id)).toList());
  });

  Future<void> markRead(String id) => _enqueue(() async {
    await _commit(state.entries.map((entry) => entry.id == id ? entry.read() : entry).toList());
  });

  Future<void> markAllRead() => _enqueue(() async {
    await _commit(state.entries.map((entry) => entry.read()).toList());
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
