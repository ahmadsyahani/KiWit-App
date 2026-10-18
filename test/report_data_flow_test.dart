import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/features/report/presentation/providers/report_providers.dart';
import 'package:kiwit_app/features/report/presentation/screens/report_screen.dart';
import 'package:kiwit_app/features/report/presentation/widgets/report_tree_card.dart';
import 'package:kiwit_app/features/report/presentation/widgets/report_period_sheet.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';

import 'inspection_sync_test.dart' show MemoryLocal, MemoryRemote, dataAt, owner;

SavedInspection reportRecord(
  String id, DateTime date, {
  String risk = 'Rendah',
  bool synced = true,
  String userId = owner,
}) => SavedInspection(
  id: id, ownerId: userId,
  data: dataAt(date).copyWith(
    imagePath: '', inspectionId: id, riskStatus: risk,
  ),
  savedAt: date, notes: 'Catatan $id', inspectorName: 'Petugas',
  rayon: 'Rayon 3', isSynced: synced,
);

void main() {
  test('month selection uses local calendar month and year, including a UTC timestamp', () {
    final data = projectReportData([
      reportRecord('previous-month', DateTime(2025, 12, 31, 23, 59)),
      reportRecord('last-year', DateTime(2025, 1, 2)),
      reportRecord('first-minute', DateTime(2026, 1, 1, 0, 1).toUtc()),
      reportRecord('january', DateTime(2026, 1, 20)),
      reportRecord('next-month', DateTime(2026, 2, 1)),
    ], now: DateTime(2026, 1, 21));
    expect(data.inspectedCount, 2);
    expect(data.visibleRecords.map((r) => r.id), ['january', 'first-minute']);
    expect(data.totalStored, 5);
    expect(reportMonthLabel(DateTime(2027, 1)), 'Januari 2027');
  });

  test('risk and pending filters do not alter period summary totals', () {
    final records = [
      reportRecord('critical', DateTime(2026, 10, 18), risk: 'Ekstrem'),
      reportRecord('high', DateTime(2026, 10, 17), risk: 'Tinggi', synced: false),
      reportRecord('low', DateTime(2026, 10, 16)),
    ];
    final critical = projectReportData(records, now: DateTime(2026, 10),
      filter: ReportFilter.critical, query: ' MAHONI ');
    expect(critical.visibleRecords.single.id, 'critical');
    expect(critical.inspectedCount, 3);
    expect(critical.criticalCount, 1);
    expect(critical.highCount, 1);
    expect(critical.pendingCount, 1);
    final pending = projectReportData(records, now: DateTime(2026, 10),
      filter: ReportFilter.pending, query: 'high');
    expect(pending.visibleRecords.single.id, 'high');
    expect(projectReportData(records, now: DateTime(2026, 10),
      query: 'not-found').visibleRecords, isEmpty);
  });

  test('custom month matches both month and year without changing summary filters', () {
    final records = [
      reportRecord('feb-2025-high', DateTime(2025, 2, 1).toUtc(), risk: 'Tinggi'),
      reportRecord('feb-2025-low', DateTime(2025, 2, 28, 23, 59)),
      reportRecord('feb-2026', DateTime(2026, 2, 1)),
      reportRecord('mar-2025', DateTime(2025, 3, 1)),
    ];
    final result = projectReportData(records, now: DateTime(2026, 10),
      period: ReportPeriod.customMonth, customDate: DateTime(2025, 2),
      filter: ReportFilter.high);
    expect(result.inspectedCount, 2);
    expect(result.visibleRecords.single.id, 'feb-2025-high');
    expect(result.highCount, 1);
    expect(reportPeriodLabel(ReportPeriod.customMonth,
      DateTime(2026, 10), DateTime(2025, 2)), 'Februari 2025');
  });

  test('whole year includes January through December and excludes adjacent years', () {
    final result = projectReportData([
      reportRecord('previous', DateTime(2024, 12, 31, 23, 59)),
      reportRecord('january', DateTime(2025, 1, 1)),
      reportRecord('december', DateTime(2025, 12, 31, 23, 59)),
      reportRecord('next', DateTime(2026, 1, 1)),
    ], now: DateTime(2026, 10), period: ReportPeriod.customYear,
      customDate: DateTime(2025));
    expect(result.visibleRecords.map((record) => record.id), ['december', 'january']);
    expect(reportPeriodLabel(ReportPeriod.customYear,
      DateTime(2026, 10), DateTime(2025)), 'Tahun 2025');
  });

  test('custom period stays fixed when current month changes', () async {
    final controller = InspectionController(ownerId: owner, local: MemoryLocal([
      reportRecord('old-february', DateTime(2025, 2)),
      reportRecord('november', DateTime(2026, 11)),
    ]));
    final container = ProviderContainer(overrides: [
      reportNowProvider.overrideWith((ref) => DateTime(2026, 10)),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    container.read(reportCustomDateProvider.notifier).state = DateTime(2025, 2);
    container.read(reportPeriodProvider.notifier).state = ReportPeriod.customMonth;
    container.read(reportNowProvider.notifier).state = DateTime(2026, 11);
    expect(container.read(reportDataProvider).requireValue.visibleRecords.single.id, 'old-february');
    container.read(reportPeriodProvider.notifier).state = ReportPeriod.currentMonth;
    expect(container.read(reportDataProvider).requireValue.visibleRecords.single.id, 'november');
  });

  test('all-time includes older inspections and empty storage produces no example reports', () {
    final old = reportRecord('old', DateTime(2025, 3));
    expect(projectReportData([old], now: DateTime(2026, 10)).visibleRecords, isEmpty);
    expect(projectReportData([old], now: DateTime(2026, 10),
      period: ReportPeriod.allTime).visibleRecords.single, same(old));
    final empty = projectReportData([], now: DateTime(2026, 10));
    expect(empty.visibleRecords, isEmpty);
    expect(empty.inspectedCount, 0);
  });

  test('saving offline and retrying cloud synchronization updates reports and pending totals', () async {
    final remote = MemoryRemote()..failPush = true;
    final controller = InspectionController(ownerId: owner, local: MemoryLocal(), remote: remote);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      reportNowProvider.overrideWith((ref) => DateTime(2026, 10, 18)),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    final saved = await controller.save(
      data: dataAt(DateTime(2026, 10, 18)),
      notes: '', inspectorName: 'Petugas', rayon: 'Rayon 3',
    );
    await controller.refresh();
    var reports = container.read(reportDataProvider).requireValue;
    expect(reports.visibleRecords.single.id, saved.id);
    expect(reports.pendingCount, 1);

    remote.failPush = false;
    await controller.refresh();
    reports = container.read(reportDataProvider).requireValue;
    expect(reports.visibleRecords.single.id, saved.id);
    expect(reports.pendingCount, 0);
    expect(reports.visibleRecords.single.isSynced, isTrue);
  });

  test('advancing the calendar updates monthly reports without changing records', () async {
    final controller = InspectionController(ownerId: owner, local: MemoryLocal([
      reportRecord('october', DateTime(2026, 10, 31, 23, 59)),
      reportRecord('november', DateTime(2026, 11, 1)),
    ]));
    final container = ProviderContainer(overrides: [
      reportNowProvider.overrideWith((ref) => DateTime(2026, 10, 31)),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    expect(container.read(reportDataProvider).requireValue.visibleRecords.single.id, 'october');
    container.read(reportNowProvider.notifier).state = DateTime(2026, 11, 1);
    expect(container.read(reportDataProvider).requireValue.visibleRecords.single.id, 'november');
  });

  test('changing accounts clears report search, filters, period and previous records', () async {
    final account = StateProvider<String?>((ref) => owner);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
      reportNowProvider.overrideWith((ref) => DateTime(2026, 10)),
      inspectionControllerProvider.overrideWith((ref) {
        final id = ref.watch(currentUserIdProvider) ?? 'guest';
        return InspectionController(ownerId: id, local: MemoryLocal(
          id == owner ? [reportRecord('private', DateTime(2026, 10))] : [],
        ));
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(inspectionControllerProvider.notifier).refresh();
    container.read(reportCustomDateProvider.notifier).state = DateTime(2020, 8);
    container.read(reportPeriodProvider.notifier).state = ReportPeriod.customMonth;
    container.read(reportSearchProvider.notifier).state = 'private';
    container.read(reportFilterProvider.notifier).state = ReportFilter.pending;
    container.read(reportDataProvider);
    container.read(account.notifier).state = 'other-account';
    await container.read(inspectionControllerProvider.notifier).refresh();
    expect(container.read(reportDataProvider).requireValue.visibleRecords, isEmpty);
    expect(container.read(reportPeriodProvider), ReportPeriod.currentMonth);
    expect(container.read(reportCustomDateProvider), DateTime(2026, 10));
    expect(container.read(reportFilterProvider), ReportFilter.all);
    expect(container.read(reportSearchProvider), '');
  });

  testWidgets('older reports can be opened from all-time on a narrow screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = reportRecord('chosen-report', DateTime(2026, 9, 17)).copyWith(
      data: dataAt(DateTime(2026, 9, 17)).copyWith(
        imagePath: '', inspectionId: 'chosen-report',
        treeSpecies: 'Pohon Mahoni dengan nama panjang di area inspeksi',
        locationAddress: 'Jalan dengan nama panjang di wilayah Surabaya Timur',
      ),
    );
    final controller = InspectionController(ownerId: owner, local: MemoryLocal([record]));
    await controller.refresh();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(owner),
        reportNowProvider.overrideWith((ref) => DateTime(2026, 10, 18)),
        inspectionControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.4),
            padding: const EdgeInsets.only(bottom: 92),
          ),
          child: child!,
        ),
        home: const ReportScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Oktober 2026'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Lihat semua waktu'), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada inspeksi bulan ini'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lihat semua waktu'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(ReportTreeCard), 200,
      scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byType(ReportTreeCard));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(ReportTreeCard));
    await tester.pumpAndSettle();
    expect(find.text('Detail inspeksi'), findsOneWidget);
    expect(find.text(record.data.treeSpecies), findsOneWidget);
    await tester.scrollUntilVisible(find.text(record.data.locationAddress), 240,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text(record.data.locationAddress), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cloud read failure is visible and does not produce dummy report cards', (tester) async {
    final remote = MemoryRemote()..failFetch = true;
    final controller = InspectionController(ownerId: owner, local: MemoryLocal(), remote: remote);
    await controller.refresh();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(owner),
        inspectionControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MaterialApp(home: ReportScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Data cloud belum dapat dimuat'), 200,
      scrollable: find.byType(Scrollable).first);
    expect(find.byType(ReportTreeCard), findsNothing);
    expect(find.text('Data cloud belum dapat dimuat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('period picker applies custom month, whole year, all time and current month', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = InspectionController(ownerId: owner, local: MemoryLocal([
      reportRecord('february-2025', DateTime(2025, 2, 10)),
      reportRecord('september-2025', DateTime(2025, 9, 10)),
      reportRecord('february-2026', DateTime(2026, 2, 10)),
    ]));
    await source.refresh();
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      reportNowProvider.overrideWith((ref) => DateTime(2026, 10)),
      inspectionControllerProvider.overrideWith((ref) => source),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const MaterialApp(home: ReportScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Oktober 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih bulan dan tahun'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Februari').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2025');
    await tester.tap(find.text('Terapkan periode'));
    await tester.pumpAndSettle();
    expect(container.read(reportDataProvider).requireValue.visibleRecords.single.id, 'february-2025');
    expect(find.widgetWithText(TextButton, 'Februari 2025'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(TextButton, 'Februari 2025'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text, '2025');
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua bulan').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terapkan periode'));
    await tester.pumpAndSettle();
    expect(container.read(reportDataProvider).requireValue.inspectedCount, 2);
    expect(find.widgetWithText(TextButton, 'Tahun 2025'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Tahun 2025'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semua waktu'));
    await tester.pumpAndSettle();
    expect(container.read(reportDataProvider).requireValue.inspectedCount, 3);
    await tester.tap(find.widgetWithText(TextButton, 'Semua waktu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bulan ini').last);
    await tester.pumpAndSettle();
    expect(container.read(reportPeriodProvider), ReportPeriod.currentMonth);
    expect(container.read(reportDataProvider).requireValue.inspectedCount, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('year validation and cancelling work on small screens with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    (ReportPeriod, DateTime)? selection;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.4)),
        child: child!),
      home: Builder(builder: (context) => Scaffold(body: TextButton(
        child: const Text('Buka periode'),
        onPressed: () async {
          selection = await showModalBottomSheet<(ReportPeriod, DateTime)>(
            context: context, isScrollControlled: true, showDragHandle: true,
            builder: (_) => ReportPeriodSheet(period: ReportPeriod.customMonth,
              customDate: DateTime(2025, 12), now: DateTime(2026, 10)),
          );
        },
      ))),
    ));
    await tester.tap(find.text('Buka periode'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '0000');
    await tester.ensureVisible(find.text('Terapkan periode'));
    await tester.tap(find.text('Terapkan periode'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan tahun antara 1 dan 9999.'), findsOneWidget);
    expect(selection, isNull);
    expect(tester.takeException(), isNull);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(selection, isNull);
    expect(find.text('Buka periode'), findsOneWidget);
  });
}
