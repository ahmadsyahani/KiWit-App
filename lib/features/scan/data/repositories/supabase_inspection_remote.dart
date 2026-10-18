import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/inspection_result_data.dart';
import '../models/saved_inspection.dart';
import 'inspection_controller.dart';

class SupabaseInspectionRemote implements InspectionRemoteStorage {
  SupabaseInspectionRemote(this.client, this.ownerId);

  static const photoBucket = 'kiwit-inspection-photos';
  final SupabaseClient client;
  final String ownerId;
  RealtimeChannel? _channel;
  bool _disposed = false;

  @override
  bool get canSync => !_disposed && client.auth.currentUser?.id == ownerId;

  void _requireSession() {
    if (!canSync) {
      throw const InspectionSyncException('Masuk kembali untuk menyinkronkan inspeksi.');
    }
  }

  @override
  Future<SavedInspection> push(SavedInspection record) async {
    _requireSession();
    if (record.ownerId != ownerId) {
      throw const InspectionSyncException('Data inspeksi tidak sesuai akun.');
    }
    final photoPath = '$ownerId/${record.id}.jpg';
    await client.storage.from(photoBucket).upload(
      photoPath,
      File(record.data.imagePath),
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    ).timeout(const Duration(seconds: 30));
    _requireSession();
    final payload = record.data.toJson()..remove('imagePath');
    try {
      await client.from('inspections').upsert({
        'id': record.id,
        'user_id': ownerId,
        'scan_timestamp': record.data.scanTimestamp.toUtc().toIso8601String(),
        'saved_at': record.savedAt.toUtc().toIso8601String(),
        'species_name': record.data.treeSpecies,
        'health_score': record.data.healthScore,
        'risk_status': record.data.riskStatus,
        'location_address': record.data.locationAddress,
        'latitude': record.data.latitude,
        'longitude': record.data.longitude,
        'inspector_name': record.inspectorName,
        'rayon': record.rayon,
        'notes': record.notes,
        'payload': payload,
        'photo_path': photoPath,
      }, onConflict: 'id').timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      _rethrowDatabaseError(error);
    }
    return record.copyWith(photoStoragePath: photoPath, isSynced: true);
  }

  @override
  Future<List<SavedInspection>> fetchAll() async {
    _requireSession();
    final records = <SavedInspection>[];
    const pageSize = 200;
    try {
      for (var offset = 0; ; offset += pageSize) {
        _requireSession();
        final rows = await client.from('inspections')
            .select()
            .eq('user_id', ownerId)
            .order('scan_timestamp', ascending: false)
            .order('id')
            .range(offset, offset + pageSize - 1)
            .timeout(const Duration(seconds: 20));
        _requireSession();
        for (final row in rows) {
          if (row['user_id'] != ownerId) {
            throw const InspectionSyncException('Data inspeksi tidak sesuai akun.');
          }
          records.add(SavedInspection(
            id: row['id'] as String,
            ownerId: ownerId,
            data: InspectionResultData.fromJson(
              Map<String, dynamic>.from(row['payload'] as Map),
            ).copyWith(imagePath: ''),
            savedAt: DateTime.parse(row['saved_at'] as String).toLocal(),
            notes: row['notes'] as String? ?? '',
            inspectorName: row['inspector_name'] as String? ?? '',
            rayon: row['rayon'] as String? ?? '',
            photoStoragePath: row['photo_path'] as String?,
            isSynced: true,
          ));
        }
        if (rows.length < pageSize) break;
      }
    } on PostgrestException catch (error) {
      _rethrowDatabaseError(error);
    }
    return records;
  }

  Never _rethrowDatabaseError(PostgrestException error) {
    if (error.code == 'PGRST205' || error.code == '42P01' || error.code == '42501') {
      throw const InspectionSyncException(
        'Penyimpanan cloud belum siap. Data tetap tersimpan di perangkat.',
      );
    }
    throw error;
  }

  @override
  Future<String?> photoUrl(String path) async {
    _requireSession();
    if (!path.startsWith('$ownerId/')) return null;
    return client.storage.from(photoBucket).createSignedUrl(path, 3600)
        .timeout(const Duration(seconds: 15));
  }

  @override
  void listen(void Function() onChange) {
    if (!canSync || _channel != null) return;
    _channel = client.channel('inspections:$ownerId:${const Uuid().v4()}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inspections',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: ownerId,
          ),
          callback: (_) => onChange(),
        ).subscribe((status, error) {
          if (status == RealtimeSubscribeStatus.subscribed) onChange();
        });
  }

  @override
  void dispose() {
    _disposed = true;
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(client.removeChannel(channel).then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      ));
    }
  }
}
