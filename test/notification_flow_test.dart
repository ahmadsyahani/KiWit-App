import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/features/notifications/data/notification_entry.dart';
import 'package:kiwit_app/features/notifications/data/notification_storage.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_bell.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_controller.dart';
import 'package:kiwit_app/features/notifications/presentation/notification_screen.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/saved_inspection_detail_screen.dart';
import 'inspection_sync_test.dart' show MemoryLocal, MemoryRemote, owner, recordAt;

class MemoryNotifications implements NotificationStorage {
  List<NotificationEntry> entries = [];
  bool failWrites = false;
  bool failLoad = false;
  Completer<void>? loadGate;
  @override
  Future<List<NotificationEntry>> load() async {
    await loadGate?.future;
    if (failLoad) throw const FileSystemException('read failure');
    return entries.map((entry) => NotificationEntry.fromJson(entry.toJson())).toList();
  }
  @override
  Future<void> write(List<NotificationEntry> next) async {
    if (failWrites) throw const FileSystemException('write failure');
    entries = next.map((entry) => NotificationEntry.fromJson(entry.toJson())).toList();
  }
}

SavedInspection inspection(String id, String risk, {bool synced = true, String userId = owner,
    DateTime? at}) {
  final record = recordAt(id, at ?? DateTime(2026, 10, 18, 10), synced: synced, userId: userId);
  return record.copyWith(data: record.data.copyWith(
    riskStatus: risk, imagePath: '', inspectionId: id,
    locationAddress: 'Jalan Kenanga, Surabaya',
  ));
}

void main() {
  late MemoryNotifications storage;
  late NotificationController inbox;
  setUp(() {
    storage = MemoryNotifications();
    inbox = NotificationController(ownerId: owner, storage: storage,
      now: () => DateTime(2026, 10, 18, 12));
  });
  tearDown(() => inbox.dispose());

  test('risk notices follow actual account feed and normalize critical labels', () async {
    await inbox.receive(InspectionFeed(records: [
      inspection('low', 'Rendah'), inspection('medium', 'Sedang'),
      inspection('high', 'Tinggi'), inspection('critical', 'Ekstrem'),
      inspection('foreign', 'Kritis', userId: 'other'),
    ]));
    expect(inbox.state.entries.map((entry) => entry.recordId).toSet(), {'high', 'critical'});
    expect(inbox.state.unreadCount, 2);
    expect(inbox.state.entries.any((entry) => entry.title.contains('kritis')), isTrue);
    expect(inbox.state.entries.first.message, contains('pemeriksaan lanjutan'));
  });

  test('refresh does not duplicate notices or reset read state', () async {
    final feed = InspectionFeed(records: [inspection('high', 'Tinggi')]);
    await inbox.receive(feed);
    final id = inbox.state.entries.single.id;
    await inbox.markRead(id);
    await inbox.receive(feed);
    expect(inbox.state.entries, hasLength(1));
    expect(inbox.state.unreadCount, 0);
    inbox.dispose();
    inbox = NotificationController(ownerId: owner, storage: storage);
    await inbox.receive(feed);
    expect(inbox.state.unreadCount, 0);
    expect(storage.entries.single.isRead, isTrue);
  });

  test('new severity is unread; downgraded/deleted risk notices are removed', () async {
    await inbox.receive(InspectionFeed(records: [inspection('tree', 'Tinggi')]));
    await inbox.markAllRead();
    await inbox.receive(InspectionFeed(records: [inspection('tree', 'Kritis')]));
    expect(inbox.state.entries, hasLength(1));
    expect(inbox.state.unreadCount, 1);
    await inbox.receive(InspectionFeed(records: [inspection('tree', 'Rendah')]));
    expect(inbox.state.entries, isEmpty);
  });

  test('normal automatic sync produces no repetitive status notices', () async {
    final record = inspection('new', 'Rendah', synced: false);
    await inbox.receive(InspectionFeed(records: [record]));
    await inbox.receive(InspectionFeed(records: [record], syncing: true));
    await inbox.receive(InspectionFeed(records: [record.copyWith(isSynced: true)]));
    expect(inbox.state.entries, isEmpty);
  });

  test('pending sync is one summary; retries preserve read status; new records alert', () async {
    final first = inspection('one', 'Rendah', synced: false);
    var feed = InspectionFeed(records: [first], syncIssue: 'Offline');
    await inbox.receive(feed);
    expect(inbox.state.entries.single.kind, NotificationKind.syncPending);
    await inbox.markAllRead();
    await inbox.receive(InspectionFeed(records: [first], syncing: true));
    await inbox.receive(feed);
    expect(inbox.state.entries, hasLength(1));
    expect(inbox.state.unreadCount, 0);
    feed = InspectionFeed(records: [first, inspection('two', 'Rendah', synced: false)], syncIssue: 'Offline');
    await inbox.receive(feed);
    expect(inbox.state.entries, hasLength(1));
    expect(inbox.state.entries.single.title, contains('2 inspeksi'));
    expect(inbox.state.unreadCount, 1);
  });

  test('resolved pending batch produces exactly one completion summary', () async {
    final record = inspection('pending', 'Rendah', synced: false);
    await inbox.receive(InspectionFeed(records: [record], syncIssue: 'Offline'));
    await inbox.markAllRead();
    final synced = InspectionFeed(records: [record.copyWith(isSynced: true)]);
    await inbox.receive(synced);
    await inbox.receive(synced);
    expect(inbox.state.entries, hasLength(1));
    expect(inbox.state.entries.single.kind, NotificationKind.syncComplete);
    expect(inbox.state.unreadCount, 1);
  });

  test('deleted pending record does not create a false sync success', () async {
    await inbox.receive(InspectionFeed(records: [inspection('deleted', 'Rendah', synced: false)],
      syncIssue: 'Offline'));
    await inbox.receive(InspectionFeed(records: []));
    expect(inbox.state.entries, isEmpty);
  });

  test('connection issue without pending photos is actionable and clears on recovery', () async {
    await inbox.receive(InspectionFeed(records: [], syncIssue: 'Cloud unavailable'));
    expect(inbox.state.entries.single.kind, NotificationKind.syncIssue);
    await inbox.markAllRead();
    await inbox.receive(InspectionFeed(records: [], syncIssue: 'Cloud unavailable'));
    expect(inbox.state.unreadCount, 0);
    await inbox.receive(InspectionFeed(records: []));
    expect(inbox.state.entries, isEmpty);
  });

  test('disk failure is visible; retry persists read state', () async {
    await inbox.receive(InspectionFeed(records: [inspection('risk', 'Tinggi')]));
    storage.failWrites = true;
    await inbox.markAllRead();
    expect(inbox.state.unreadCount, 0);
    expect(inbox.state.storageIssue, isNotNull);
    expect(storage.entries.single.isRead, isFalse);
    storage.failWrites = false;
    await inbox.markAllRead();
    expect(inbox.state.storageIssue, isNull);
    expect(storage.entries.single.isRead, isTrue);
  });

  test('feed updates wait for stored read state before reconciliation', () async {
    await inbox.receive(InspectionFeed(records: [inspection('risk', 'Tinggi')]));
    await inbox.markAllRead();
    inbox.dispose();
    storage.loadGate = Completer<void>();
    inbox = NotificationController(ownerId: owner, storage: storage);
    final update = inbox.receive(InspectionFeed(records: [inspection('risk', 'Tinggi')]));
    expect(inbox.state.loading, isTrue);
    storage.loadGate!.complete();
    await update;
    expect(inbox.state.unreadCount, 0);
  });

  test('file storage roundtrip preserves account, JSON and read status', () async {
    final directory = await Directory.systemTemp.createTemp('kiwit_notifications_');
    try {
      final fileStore = FileNotificationStorage(owner, documentsDirectory: () async => directory);
      await inbox.receive(InspectionFeed(records: [inspection('risk', 'Tinggi')]));
      await fileStore.write(inbox.state.entries);
      await fileStore.write(inbox.state.entries.map((entry) => entry.read()).toList());
      expect((await fileStore.load()).single.isRead, isTrue);
      final other = FileNotificationStorage('other', documentsDirectory: () async => directory);
      expect(await other.load(), isEmpty);
      final file = File('${directory.path}/notifications_v1/$owner/inbox.json');
      final doc = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      doc['ownerId'] = 'other';
      await file.writeAsString(jsonEncode(doc));
      await expectLater(fileStore.load(), throwsFormatException);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('provider receives real save/sync updates, not sample notifications', () async {
    final remote = MemoryRemote()..failPush = true;
    final inspections = InspectionController(ownerId: owner, local: MemoryLocal(), remote: remote);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      notificationStorageProvider.overrideWithValue(storage),
      inspectionControllerProvider.overrideWith((ref) => inspections),
    ]);
    addTearDown(container.dispose);
    container.read(notificationControllerProvider);
    await inspections.refresh();
    final saved = await inspections.save(data: inspection('real', 'Tinggi').data,
      notes: '', inspectorName: 'Petugas', rayon: 'Rayon 3');
    await inspections.refresh();
    final notifications = container.read(notificationControllerProvider.notifier);
    await notifications.receive(container.read(inspectionControllerProvider).requireValue);
    expect(container.read(notificationControllerProvider).entries
      .where((entry) => entry.kind == NotificationKind.risk).single.recordId, saved.id);
    expect(container.read(notificationControllerProvider).entries
      .where((entry) => entry.kind == NotificationKind.syncPending), hasLength(1));
    remote.failPush = false;
    await inspections.refresh();
    await notifications.receive(container.read(inspectionControllerProvider).requireValue);
    expect(container.read(notificationControllerProvider).entries
      .where((entry) => entry.kind == NotificationKind.syncPending), isEmpty);
    expect(container.read(notificationControllerProvider).entries
      .where((entry) => entry.kind == NotificationKind.syncComplete), hasLength(1));
  });

  test('changing account clears badge and keeps read state isolated', () async {
    final account = StateProvider<String?>((ref) => owner);
    final stores = <String, MemoryNotifications>{};
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
      notificationStorageProvider.overrideWith((ref) => stores.putIfAbsent(
        ref.watch(currentUserIdProvider) ?? 'guest', MemoryNotifications.new)),
      inspectionControllerProvider.overrideWith((ref) {
        final id = ref.watch(currentUserIdProvider) ?? 'guest';
        return InspectionController(ownerId: id,
          local: MemoryLocal(id == owner ? [inspection('private', 'Tinggi')] : []));
      }),
    ]);
    addTearDown(container.dispose);
    container.read(notificationControllerProvider);
    await container.read(inspectionControllerProvider.notifier).refresh();
    await container.read(notificationControllerProvider.notifier)
      .receive(container.read(inspectionControllerProvider).requireValue);
    await container.read(notificationControllerProvider.notifier).markAllRead();
    container.read(account.notifier).state = 'other';
    expect(container.read(notificationControllerProvider).entries, isEmpty);
    await container.read(inspectionControllerProvider.notifier).refresh();
    await container.read(notificationControllerProvider.notifier)
      .receive(container.read(inspectionControllerProvider).requireValue);
    expect(container.read(notificationControllerProvider).entries, isEmpty);
    container.read(account.notifier).state = owner;
    await container.read(inspectionControllerProvider.notifier).refresh();
    await container.read(notificationControllerProvider.notifier)
      .receive(container.read(inspectionControllerProvider).requireValue);
    expect(container.read(notificationControllerProvider).entries.single.isRead, isTrue);
  });

  testWidgets('bell opens inbox; read all updates badge; risk tap opens exact inspection', (tester) async {
    final record = inspection('selected', 'Tinggi', at: DateTime.now());
    final inspections = InspectionController(ownerId: owner, local: MemoryLocal([record]));
    await inspections.refresh();
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      notificationStorageProvider.overrideWithValue(MemoryNotifications()),
      inspectionControllerProvider.overrideWith((ref) => inspections),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: Scaffold(body: Center(child: NotificationBell())))));
    await tester.pumpAndSettle();
    expect(container.read(notificationControllerProvider).unreadCount, 1);
    await tester.tap(find.byType(NotificationBell));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    await tester.tap(find.text('Tandai semua dibaca'));
    await tester.pumpAndSettle();
    expect(container.read(notificationControllerProvider).unreadCount, 0);
    await tester.tap(find.text('Inspeksi berisiko tinggi'));
    await tester.pumpAndSettle();
    expect(find.text('Detail inspeksi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('selected'), 240,
      scrollable: find.descendant(of: find.byType(SavedInspectionDetailScreen),
        matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('pending notice opens actual pending list and sync action resolves it', (tester) async {
    final remote = MemoryRemote()..failPush = true;
    final record = inspection('offline-tree', 'Rendah', synced: false);
    final inspections = InspectionController(ownerId: owner, local: MemoryLocal([record]), remote: remote);
    await inspections.refresh();
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      notificationStorageProvider.overrideWithValue(MemoryNotifications()),
      inspectionControllerProvider.overrideWith((ref) => inspections),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: NotificationScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 inspeksi belum tersinkron'));
    await tester.pumpAndSettle();
    expect(find.text('Inspeksi tertunda'), findsOneWidget);
    expect(find.text('Pohon Mahoni'), findsOneWidget);
    remote.failPush = false;
    await tester.tap(find.text('Sinkronkan sekarang'));
    await tester.pumpAndSettle();
    expect(find.text('Data sudah tersinkron'), findsOneWidget);
    expect(find.text('Inspeksi tertunda'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('narrow screen, larger text and previous-day groups fit without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.now();
    final inspections = InspectionController(ownerId: owner, local: MemoryLocal([
      inspection('today', 'Kritis', at: now),
      inspection('old', 'Tinggi', at: DateTime(now.year, now.month, now.day - 1)),
    ]));
    await inspections.refresh();
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      notificationStorageProvider.overrideWithValue(MemoryNotifications()),
      inspectionControllerProvider.overrideWith((ref) => inspections),
    ], child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)), child: child!),
      home: const NotificationScreen(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sebelumnya'), 180,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Sebelumnya'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty inbox has no badge or dummy alerts', (tester) async {
    final inspections = InspectionController(ownerId: owner, local: MemoryLocal());
    await inspections.refresh();
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      notificationStorageProvider.overrideWithValue(MemoryNotifications()),
      inspectionControllerProvider.overrideWith((ref) => inspections),
    ], child: const MaterialApp(home: NotificationScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada notifikasi'), findsOneWidget);
    expect(find.textContaining('Inspeksi berisiko'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
