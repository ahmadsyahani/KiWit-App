import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/widgets/risk_badge.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/report/presentation/providers/report_providers.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_result_screen.dart';
import 'inspection_sync_test.dart' show MemoryLocal, MemoryRemote, owner, dataAt, recordAt;
import 'inspection_detail_test.dart' show showDetail;

InspectionResultData pendingPhoto() => InspectionResultData.unassessed(
  imagePath: '', inspectionId: 'photo-without-assessment',
  locationAddress: 'Lokasi pengujian', scanTimestamp: DateTime(2026, 10, 19),
  latitude: -7.25, longitude: 112.75);

void main() {
  test('assessment state survives copy, JSON and cloud retry without becoming low risk', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote()..failPush = true;
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    addTearDown(controller.dispose);
    await controller.refresh();
    final saved = await controller.save(data: pendingPhoto(), notes: 'Periksa manual',
      inspectorName: 'Petugas', rayon: 'Rayon 3');
    final restored = SavedInspection.fromJson(jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>);
    expect(restored.data.hasAssessment, isFalse);
    expect(restored.riskLevel, RiskLevel.belumDinilai);
    expect(restored.data.copyWith(locationAddress: 'Alamat baru').hasAssessment, isFalse);
    remote.failPush = false;
    await controller.refresh();
    expect(remote.records[saved.id]!.data.hasAssessment, isFalse);
    expect(remote.records[saved.id]!.riskLevel, RiskLevel.belumDinilai);
  });

  test('legacy saved assessments remain readable', () {
    final json = dataAt(DateTime(2026)).toJson()..remove('hasAssessment');
    expect(InspectionResultData.fromJson(json).hasAssessment, isTrue);
  });

  test('unassessed records are separate from every risk filter', () {
    final record = recordAt('pending', DateTime(2026, 10, 19)).copyWith(data: pendingPhoto());
    for (final filter in [ReportFilter.low, ReportFilter.medium, ReportFilter.high, ReportFilter.critical]) {
      final view = projectReportData([record], now: DateTime(2026, 10, 19), filter: filter);
      expect(view.visibleRecords, isEmpty);
      expect(view.criticalCount, 0);
      expect(view.highCount, 0);
    }
    expect(projectReportData([record], now: DateTime(2026, 10, 19),
      filter: ReportFilter.unassessed).visibleRecords.single.id, record.id);
  });

  testWidgets('unassessed result can be saved on a small screen without score or diagnosis', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final local = MemoryLocal();
    final controller = InspectionController(ownerId: owner, local: local);
    await controller.refresh();
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserProvider.overrideWithValue(null),
      userProfileProvider.overrideWith((ref) async => null),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ], child: MaterialApp(home: Builder(builder: (context) => Scaffold(body:
      TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => InspectionResultScreen(data: pendingPhoto()))), child: const Text('Buka hasil')))))));
    await tester.tap(find.text('Buka hasil'));
    await tester.pumpAndSettle();
    expect(find.text('Kondisi belum dapat dinilai'), findsOneWidget);
    expect(find.text('Skor kesehatan batang'), findsNothing);
    expect(find.text('Positif'), findsNothing);
    await tester.scrollUntilVisible(find.text('Simpan inspeksi'), 220,
      scrollable: find.descendant(of: find.byType(InspectionResultScreen),
        matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Simpan inspeksi'));
    await tester.pumpAndSettle();
    expect(local.records.single.data.hasAssessment, isFalse);
    expect(local.records.single.riskLevel, RiskLevel.belumDinilai);
    expect(find.text('Buka hasil'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('saved detail hides placeholder measurements for an unassessed photo', (tester) async {
    final record = recordAt('pending-detail', DateTime(2026, 10, 19)).copyWith(data: pendingPhoto());
    await showDetail(tester, record);
    expect(find.text('Belum dinilai'), findsOneWidget);
    expect(find.text('Skor kesehatan batang'), findsNothing);
    expect(find.text('Estimasi DBH'), findsNothing);
    expect(find.text('0 / 100'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
