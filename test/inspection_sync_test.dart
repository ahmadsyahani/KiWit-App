import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/features/home/presentation/widgets/inspection_chart_card.dart';
import 'package:kiwit_app/features/home/presentation/widgets/recent_inspection_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_local_storage.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';

const owner = '11111111-1111-4111-8111-111111111111';

InspectionResultData dataAt(DateTime timestamp) => InspectionResultData(
  imagePath: '/camera/tree.jpg',
  healthScore: 82,
  riskStatus: 'Rendah',
  ronggaBatang: 18,
  sudutKemiringan: 2,
  diameter: 40,
  isJamurPelapuk: false,
  inspectionId: '42',
  treeSpecies: 'Pohon Mahoni',
  detectedCondition: 'Kulit sehat',
  locationAddress: 'Surabaya',
  scanTimestamp: timestamp,
  latitude: -7.25,
  longitude: 112.75,
  persentaseLuka: 18,
  healthyPixelCount: 820,
  defectPixelCount: 180,
);

SavedInspection recordAt(String id, DateTime date, {bool synced = true, String userId = owner}) =>
    SavedInspection(
      id: id,
      ownerId: userId,
      data: dataAt(date),
      savedAt: date,
      notes: 'Periksa kembali minggu depan.',
      inspectorName: 'Petugas',
      rayon: 'Rayon 3',
      isSynced: synced,
    );

class MemoryLocal implements InspectionLocalStorage {
  MemoryLocal([List<SavedInspection> initial = const []]) : records = [...initial];
  List<SavedInspection> records;
  bool failWrites = false;

  @override
  Future<List<SavedInspection>> load() async => [...records];

  @override
  Future<void> write(List<SavedInspection> next) async {
    if (failWrites) throw const FileSystemException('Disk unavailable');
    records = [...next];
  }

  @override
  Future<String> preservePhoto(String id, String sourcePath) async => '/persisted/$id.jpg';
}

class MemoryRemote implements InspectionRemoteStorage {
  final records = <String, SavedInspection>{};
  final successfulPushes = <String>[];
  bool failPush = false;
  bool failFetch = false;
  bool connected = true;
  bool disposed = false;
  Completer<void>? fetchGate;
  final fetchStarted = Completer<void>();
  void Function()? onChange;

  @override
  bool get canSync => connected && !disposed;

  @override
  Future<SavedInspection> push(SavedInspection record) async {
    if (failPush) throw const InspectionSyncException('Offline');
    final synced = record.copyWith(
      isSynced: true,
      photoStoragePath: '${record.ownerId}/${record.id}.jpg',
    );
    records[record.id] = synced;
    successfulPushes.add(record.id);
    return synced;
  }

  @override
  Future<List<SavedInspection>> fetchAll() async {
    final snapshot = records.values.toList();
    if (!fetchStarted.isCompleted) fetchStarted.complete();
    final gate = fetchGate;
    if (gate != null) await gate.future;
    if (failFetch) throw const InspectionSyncException('Offline');
    return snapshot;
  }

  @override
  Future<String?> photoUrl(String path) async => null;

  @override
  void listen(void Function() listener) => onChange = listener;

  @override
  void dispose() => disposed = true;
}

void main() {
  test('seven local calendar buckets cross year boundaries without counting older or future days', () {
    final now = DateTime(2026, 1, 3, 12);
    final records = [
      recordAt('old', DateTime(2025, 12, 27, 23, 59)),
      recordAt('first', DateTime(2025, 12, 28)),
      recordAt('new-year', DateTime(2026, 1, 1, 23, 59).toUtc()),
      recordAt('today-1', DateTime(2026, 1, 3)),
      recordAt('today-2', DateTime(2026, 1, 3, 9)),
      recordAt('future', DateTime(2026, 1, 4)),
    ];
    expect(inspectionDailyCounts(records, now), [1, 0, 0, 0, 1, 0, 2]);
    expect(inspectionWeekDays(now).first, DateTime(2025, 12, 28));
    expect(inspectionWeekDays(now).last, DateTime(2026, 1, 3));
  });

  test('inspection JSON retains timestamp, GPS, photo, notes, and pending status', () {
    final record = recordAt('persisted', DateTime(2026, 10, 17, 23, 59), synced: false);
    final restored = SavedInspection.fromJson(
      jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
    );
    expect(restored.data.scanTimestamp.isAtSameMomentAs(record.data.scanTimestamp), isTrue);
    expect(restored.data.latitude, record.data.latitude);
    expect(restored.data.imagePath, record.data.imagePath);
    expect(restored.data.healthyPixelCount, 820);
    expect(restored.notes, record.notes);
    expect(restored.isSynced, isFalse);
  });

  test('invalid stored timestamp is rejected instead of becoming a new inspection today', () {
    final json = dataAt(DateTime(2026)).toJson()..['scanTimestamp'] = 'invalid';
    expect(() => InspectionResultData.fromJson(json), throwsFormatException);
  });

  test('offline save is durable and retries reuse the same cloud ID without duplicates', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote()..failPush = true;
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();

    final saved = await controller.save(
      data: dataAt(DateTime(2026, 10, 17)),
      notes: 'Catatan lapangan',
      inspectorName: 'Petugas',
      rayon: 'Rayon 3',
    );
    await controller.refresh();
    expect(local.records.single.id, saved.id);
    expect(local.records.single.data.imagePath, '/persisted/${saved.id}.jpg');
    expect(controller.state.requireValue.pendingCount, 1);
    expect(controller.state.requireValue.syncIssue, isNotNull);
    expect(remote.records, isEmpty);

    remote.failPush = false;
    await controller.refresh();
    await controller.refresh();
    expect(remote.records.keys, [saved.id]);
    expect(remote.successfulPushes, [saved.id]);
    expect(controller.state.requireValue.pendingCount, 0);
    expect(local.records.single.isSynced, isTrue);
  });

  test('a failed local commit never publishes a successful inspection or uploads it', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote();
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();
    local.failWrites = true;

    await expectLater(
      controller.save(data: dataAt(DateTime(2026)), notes: '', inspectorName: '', rayon: ''),
      throwsA(isA<FileSystemException>()),
    );
    expect(controller.state.requireValue.records, isEmpty);
    expect(local.records, isEmpty);
    expect(remote.successfulPushes, isEmpty);
  });

  test('saving stays responsive during a cloud fetch and a stale snapshot cannot erase the new record', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote()..fetchGate = Completer<void>();
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await remote.fetchStarted.future;

    final saved = await controller.save(
      data: dataAt(DateTime(2026, 10, 17)),
      notes: 'Saved while cloud was slow',
      inspectorName: '',
      rayon: '',
    ).timeout(const Duration(seconds: 2));
    expect(local.records.single.id, saved.id);
    expect(remote.fetchGate!.isCompleted, isFalse);

    remote.fetchGate!.complete();
    await controller.refresh();
    expect(controller.state.requireValue.records.single.id, saved.id);
    expect(remote.records.keys, [saved.id]);
    expect(controller.state.requireValue.pendingCount, 0);
  });

  test('realtime notification refreshes an inspection from another device', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote();
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();
    remote.records['other-device'] = recordAt('other-device', DateTime(2026, 10, 17));
    remote.onChange!();
    await Future<void>.delayed(const Duration(milliseconds: 650));

    expect(controller.state.requireValue.records.single.id, 'other-device');
    expect(local.records.single.id, 'other-device');
  });

  test('cloud read failure preserves a previously downloaded inspection', () async {
    final cached = recordAt('cached', DateTime(2026, 10, 17));
    final local = MemoryLocal([cached]);
    final remote = MemoryRemote()..failFetch = true;
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();

    expect(controller.state.requireValue.records.single.id, 'cached');
    expect(local.records.single.id, 'cached');
    expect(controller.state.requireValue.syncIssue, isNotNull);
  });

  test('a foreign-account cloud record is rejected without exposing or caching it', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote();
    remote.records['foreign'] = recordAt('foreign', DateTime(2026), userId: 'other-user');
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();

    expect(controller.state.requireValue.records, isEmpty);
    expect(local.records, isEmpty);
    expect(controller.state.requireValue.syncIssue, 'Data inspeksi tidak sesuai akun.');
  });

  testWidgets('empty chart uses zero totals and fits a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: InspectionChartCard(records: const [], today: DateTime(2026, 10, 17)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Belum ada inspeksi dalam 7 hari terakhir.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('five recent records fit long names and larger text without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = List.generate(6, (index) {
      final record = recordAt('record-$index', DateTime(2026, 10, 17 - index));
      return record.copyWith(data: record.data.copyWith(
        imagePath: '',
        treeSpecies: 'Jenis $index dengan nama pohon yang panjang',
        locationAddress: 'Jalan protokol dengan alamat inspeksi yang panjang di Surabaya',
      ));
    });
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: SingleChildScrollView(child: RecentInspectionList(records: records)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Jenis 0 dengan nama pohon yang panjang'), findsOneWidget);
    expect(find.text('Jenis 5 dengan nama pohon yang panjang'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
