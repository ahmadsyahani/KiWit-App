import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/saved_inspection_detail_screen.dart';
import 'inspection_sync_test.dart' show MemoryLocal, MemoryRemote, owner, recordAt;

SavedInspection detailRecord() {
  final record = recordAt('detail-record', DateTime(2026, 10, 18, 10, 30));
  return record.copyWith(data: record.data.copyWith(
    imagePath: '', riskStatus: 'Tinggi', riskAction: 'Periksa lebih lanjut',
  ));
}

Finder get detailScroll => find.descendant(
  of: find.byType(SavedInspectionDetailScreen),
  matching: find.byType(Scrollable),
).first;

Future<void> showDetail(WidgetTester tester, SavedInspection record, {
  double scale = 1,
  InspectionController? controller,
}) async {
  final source = controller ?? InspectionController(ownerId: owner, local: MemoryLocal([record]));
  await source.refresh();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      inspectionControllerProvider.overrideWith((ref) => source),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: SavedInspectionDetailScreen(record: record),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('risk, recommendation, score and measurements retain saved values', (tester) async {
    await showDetail(tester, detailRecord());
    expect(find.text('Detail inspeksi'), findsOneWidget);
    expect(find.text('Tinggi'), findsOneWidget);
    expect(find.text('Periksa lebih lanjut'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final value in ['82 / 100', '18.0%', '40.0 cm', '2.0°']) {
      await tester.scrollUntilVisible(find.text(value), 180, scrollable: detailScroll);
      await tester.pumpAndSettle();
      expect(find.text(value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('320px and large text support long names, IDs, coordinates and notes', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = detailRecord();
    final notes = List.filled(8, 'Periksa kondisi batang dan lingkungan sekitar pohon.').join(' ');
    final record = SavedInspection(
      id: original.id, ownerId: owner,
      data: original.data.copyWith(
        treeSpecies: 'Pohon Mahoni di sisi utara jalan dengan nama panjang',
        inspectionId: '1ca15813-bd94-4bf1-8d84-950ff3479612',
        locationAddress: 'Jalan dengan nama panjang di wilayah Surabaya Timur',
      ),
      savedAt: original.savedAt, notes: notes,
      inspectorName: 'Petugas inspeksi wilayah dengan nama panjang',
      rayon: 'Rayon 3 wilayah Surabaya Timur',
    );
    await showDetail(tester, record, scale: 1.8);
    expect(find.text(record.data.treeSpecies), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final value in [
      '18.0%', '40.0 cm', '2.0°', record.data.locationAddress,
      '-7.250000, 112.750000', record.inspectorName, record.data.inspectionId, notes,
    ]) {
      await tester.scrollUntilVisible(find.text(value), 200, scrollable: detailScroll);
      await tester.pumpAndSettle();
      expect(find.text(value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(find.byWidgetPredicate((widget) =>
      widget is SelectableText && widget.data == notes), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('missing metadata has clear fallbacks and pending sync remains visible', (tester) async {
    final original = detailRecord();
    final record = SavedInspection(
      id: original.id, ownerId: owner,
      data: InspectionResultData.fromJson({
        ...original.data.toJson(), 'latitude': null, 'longitude': null,
        'treeSpecies': ' ', 'locationAddress': ' ', 'inspectionId': ' ',
      }),
      savedAt: original.savedAt, notes: ' ', inspectorName: ' ', rayon: '',
    );
    await showDetail(tester, record);
    expect(find.text('Jenis pohon belum ditentukan'), findsOneWidget);
    for (final value in ['Lokasi belum dicatat', 'Tersimpan di perangkat',
      'Menunggu sinkronisasi', 'Belum ada catatan tambahan.']) {
      await tester.scrollUntilVisible(find.text(value), 220, scrollable: detailScroll);
      await tester.pumpAndSettle();
      expect(find.text(value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(find.text('NaN'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('open detail follows latest risk and recommendation from shared feed', (tester) async {
    final original = detailRecord();
    final remote = MemoryRemote()..records[original.id] = original;
    final controller = InspectionController(ownerId: owner,
      local: MemoryLocal([original]), remote: remote);
    await showDetail(tester, original, controller: controller);
    expect(find.text('Tinggi'), findsOneWidget);
    remote.records[original.id] = original.copyWith(data: original.data.copyWith(
      riskStatus: 'Kritis', riskAction: 'Pemeriksaan lapangan segera',
    ));
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Kritis'), findsOneWidget);
    expect(find.text('Pemeriksaan lapangan segera'), findsOneWidget);
    expect(find.text('Periksa lebih lanjut'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
