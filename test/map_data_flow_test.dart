import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/widgets/risk_badge.dart';
import 'package:kiwit_app/features/map/data/models/tree_map_model.dart';
import 'package:kiwit_app/features/map/data/repositories/tree_map_repository.dart';
import 'package:kiwit_app/features/map/presentation/controllers/map_controller.dart';
import 'package:kiwit_app/features/map/presentation/screens/map_screen.dart';
import 'package:kiwit_app/features/map/presentation/widgets/map_data_status_card.dart';
import 'package:kiwit_app/features/map/presentation/widgets/map_inspection_card.dart';
import 'package:kiwit_app/features/map/presentation/widgets/map_search_panel.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_location_picker.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_location.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/saved_inspection_detail_screen.dart';

import 'inspection_sync_test.dart' show MemoryLocal, MemoryRemote, dataAt, owner;

SavedInspection inspection(
  String id, {
  double? latitude = -7.25,
  double? longitude = 112.75,
  String risk = 'Rendah',
  String rayon = 'Rayon 3 — Sukolilo',
  String userId = owner,
}) {
  final data = dataAt(DateTime(2026, 10, 17)).toJson()
    ..['latitude'] = latitude
    ..['longitude'] = longitude
    ..['riskStatus'] = risk
    ..['imagePath'] = '';
  return SavedInspection(
    id: id, ownerId: userId,
    data: InspectionResultData.fromJson(data),
    savedAt: DateTime(2026, 10, 17),
    notes: 'Catatan $id', inspectorName: 'Petugas',
    rayon: rayon,
  );
}

class UnreadableLocal extends MemoryLocal {
  @override
  Future<List<SavedInspection>> load() async =>
      throw const FileSystemException('Cannot read local inspection data');
}

class MemoryTiles extends TileProvider {
  final _image = MemoryImage(Uint8List.fromList(
    img.encodePng(img.Image(width: 1, height: 1)),
  ));

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _image;
}

void main() {
  testWidgets('map search, selection and detail navigation fit a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = InspectionController(
      ownerId: owner, local: MemoryLocal([inspection('map-record')]),
    );
    await controller.refresh();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(owner),
        inspectionControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.3),
            padding: const EdgeInsets.only(top: 24, bottom: 92),
          ),
          child: child!,
        ),
        home: MapScreen(tileProvider: MemoryTiles()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('1 titik inspeksi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Tampilan peta'));
    await tester.pumpAndSettle();
    expect(find.text('Standar'), findsOneWidget);
    expect(find.text('Satelit'), findsOneWidget);
    expect(find.text('Topografi'), findsOneWidget);
    expect(find.text('Peta komunitas'), findsNothing);
    expect(find.text('Minimalis'), findsNothing);
    expect(find.text('Gelap'), findsNothing);
    await tester.tap(find.text('Satelit'));
    await tester.pumpAndSettle();
    expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      MapLayerType.satellite.urlTemplate);
    await tester.tap(find.text('Standar'));
    await tester.pumpAndSettle();
    expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      MapLayerType.voyager.urlTemplate);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Tutup tampilan peta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Tidak cocok');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada hasil yang cocok'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Daftar inspeksi pada peta'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar inspeksi'), findsOneWidget);
    await tester.tap(find.text('Pohon Mahoni'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat detail inspeksi'), findsOneWidget);
    final markerFinder = find.byWidgetPredicate((widget) => widget is Semantics &&
        widget.properties.label == 'Pohon Mahoni, Rendah, inspeksi 42');
    final markerRect = tester.getRect(markerFinder);
    expect(markerRect.top, greaterThan(tester.getBottomLeft(find.byType(MapSearchPanel)).dy));
    expect(markerRect.bottom, lessThan(tester.getTopLeft(find.byType(MapInspectionCard)).dy));
    await tester.tap(find.byTooltip('Tutup detail pin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Semantics &&
        widget.properties.label == 'Pohon Mahoni, Rendah, inspeksi 42'));
    await tester.pumpAndSettle();
    expect(find.text('Lihat detail inspeksi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lihat detail inspeksi'));
    await tester.pumpAndSettle();
    expect(find.text('Detail inspeksi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('-7.250000, 112.750000'), 240,
      scrollable: find.descendant(of: find.byType(SavedInspectionDetailScreen),
        matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('-7.250000, 112.750000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('empty inspection storage never creates demo map markers', () {
    final result = const TreeMapRepository().project([]);
    expect(result.totalCount, 0);
    expect(result.markers, isEmpty);
    expect(result.withoutLocation, isEmpty);
  });

  test('missing, partial, non-finite and out-of-range GPS remain unlocated', () {
    final result = const TreeMapRepository().project([
      inspection('valid'),
      inspection('zero-is-valid', latitude: 0, longitude: 0),
      inspection('missing', latitude: null, longitude: null),
      inspection('partial', longitude: null),
      inspection('nan', latitude: double.nan),
      inspection('infinite', longitude: double.infinity),
      inspection('latitude-range', latitude: 91),
      inspection('longitude-range', longitude: -181),
    ]);
    expect(result.markers.map((m) => m.id), ['valid', 'zero-is-valid']);
    expect(result.withoutLocation.length, 6);
    expect(result.matchingCount, 8);
    expect(() => TreeMapModel(inspection('missing', latitude: null)),
      throwsArgumentError);
  });

  test('rayon aliases, risk aliases and case-insensitive search filter together', () {
    final result = const TreeMapRepository().project([
      inspection('match', risk: 'Ekstrem', rayon: 'Rayon 3 — Sukolilo (Surabaya Timur II)'),
      inspection('other-rayon', risk: 'Ekstrem', rayon: 'Rayon 30'),
      inspection('other-risk', risk: 'Rendah'),
    ], rayon: 'Rayon 3', risk: RiskLevel.kritis, query: '  MAHONI  ');
    expect(result.markers.single.id, 'match');
    expect(result.totalCount, 3);
    expect(inspectionRayonOptions([
      inspection('a'),
      inspection('b', rayon: 'Rayon 3 — Sukolilo (Surabaya Timur II)'),
      inspection('c', rayon: 'Rayon 7'),
      inspection('d', rayon: ''),
    ]), containsAll(['Rayon 3', 'Rayon 7', '']));
  });

  test('duplicate display codes retain independent UUIDs and exact detail records', () {
    final a = inspection('uuid-a');
    final b = inspection('uuid-b');
    final result = const TreeMapRepository().project([a, b]);
    expect(result.markers.length, 2);
    expect(result.markers[0].record, same(a));
    expect(result.markers[1].record, same(b));
    expect(a.data.inspectionId, b.data.inspectionId);
  });

  test('a successful local save appears immediately on the map while offline', () async {
    final local = MemoryLocal();
    final remote = MemoryRemote()..failPush = true;
    final controller = InspectionController(ownerId: owner, local: local, remote: remote);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    expect(container.read(mapTreesListProvider).requireValue, isEmpty);
    final saved = await controller.save(
      data: dataAt(DateTime(2026, 10, 17)),
      notes: 'Saved offline', inspectorName: 'Petugas', rayon: 'Rayon 3',
    );
    await controller.refresh();
    final marker = container.read(mapTreesListProvider).requireValue.single;
    expect(marker.id, saved.id);
    expect(marker.isSynced, isFalse);
    expect(marker.latitude, saved.data.latitude);
    expect(local.records.single.id, marker.id);
  });

  test('realtime cloud updates refresh selected details and removed records disappear', () async {
    final remote = MemoryRemote();
    remote.records['stable-id'] = inspection('stable-id');
    final controller = InspectionController(
      ownerId: owner, local: MemoryLocal(), remote: remote,
    );
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    container.read(selectedTreeMapIdProvider.notifier).state = 'stable-id';
    expect(container.read(selectedTreeMapItemProvider)?.riskLevel, RiskLevel.rendah);

    remote.records['stable-id'] = inspection('stable-id', risk: 'Tinggi');
    remote.onChange!();
    await Future<void>.delayed(const Duration(milliseconds: 650));
    expect(container.read(selectedTreeMapItemProvider)?.riskLevel, RiskLevel.tinggi);

    remote.records.clear();
    await controller.refresh();
    expect(container.read(mapTreesListProvider).requireValue, isEmpty);
    expect(container.read(selectedTreeMapItemProvider), isNull);
  });

  test('filtering clears an incompatible selected pin', () async {
    final controller = InspectionController(
      ownerId: owner, local: MemoryLocal([inspection('selected')]),
    );
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await controller.refresh();
    container.read(selectedTreeMapIdProvider.notifier).state = 'selected';
    expect(container.read(selectedTreeMapItemProvider)?.id, 'selected');
    container.read(selectedRiskFilterProvider.notifier).state = RiskLevel.kritis;
    expect(container.read(mapTreesListProvider).requireValue, isEmpty);
    expect(container.read(selectedTreeMapItemProvider), isNull);
  });

  test('switching accounts clears markers, selection and filters from the previous account', () async {
    final account = StateProvider<String?>((ref) => owner);
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
      inspectionControllerProvider.overrideWith((ref) {
        final userId = ref.watch(currentUserIdProvider) ?? 'guest';
        return InspectionController(ownerId: userId, local: MemoryLocal(
          userId == owner ? [inspection('private-record')] : [],
        ));
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(inspectionControllerProvider.notifier).refresh();
    container.read(mapSearchQueryProvider.notifier).state = 'Mahoni';
    container.read(selectedTreeMapIdProvider.notifier).state = 'private-record';
    expect(container.read(mapTreesListProvider).requireValue.single.id, 'private-record');

    container.read(account.notifier).state = 'second-account';
    await container.read(inspectionControllerProvider.notifier).refresh();
    expect(container.read(mapTreesListProvider).requireValue, isEmpty);
    expect(container.read(selectedTreeMapItemProvider), isNull);
    expect(container.read(mapSearchQueryProvider), '');
    expect(container.read(selectedRayonFilterProvider), 'Semua Rayon');
  });

  test('a local read error reaches the map instead of becoming an empty or demo map', () async {
    final controller = InspectionController(ownerId: owner, local: UnreadableLocal());
    final container = ProviderContainer(overrides: [
      inspectionControllerProvider.overrideWith((ref) => controller),
    ]);
    addTearDown(container.dispose);
    await expectLater(controller.refresh(), throwsA(isA<FileSystemException>()));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(mapInspectionDataProvider).hasError, isTrue);
  });

  testWidgets('cloud failure is not presented as an empty successful account', (tester) async {
    final feed = InspectionFeed(records: [], syncIssue: 'Offline');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MapDataStatusCard(
      data: AsyncData(const TreeMapRepository().project([])),
      feed: AsyncData(feed), isGuest: false,
      onRefresh: () {}, onStartScan: () {}, onWithoutLocation: () {},
    ))));
    expect(find.text('Data cloud belum dapat dimuat'), findsOneWidget);
    expect(find.text('Belum ada inspeksi tersimpan'), findsNothing);
  });

  testWidgets('optional location correction returns the chosen coordinates', (tester) async {
    InspectionLocation? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(body: TextButton(
        onPressed: () async {
          selected = await Navigator.push<InspectionLocation>(context, MaterialPageRoute(
            builder: (_) => InspectionLocationPicker(
              initialLocation: const InspectionLocation(latitude: -7.28, longitude: 112.79),
              tileProvider: MemoryTiles()),
          ));
        },
        child: const Text('Pilih lokasi'),
      )),
    )));
    await tester.tap(find.text('Pilih lokasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan lokasi ini'));
    await tester.pumpAndSettle();
    expect(selected?.latitude, -7.28);
    expect(selected?.longitude, 112.79);
    expect(selected?.isValid, isTrue);
  });

  testWidgets('selected marker opens its actual inspection detail on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final record = inspection('chosen-record').copyWith(data:
      inspection('chosen-record').data.copyWith(
        treeSpecies: 'Mahoni di sisi utara jalan dengan nama yang panjang',
        locationAddress: 'Jalan dengan nama panjang di wilayah Surabaya Timur',
      ));
    final controller = InspectionController(ownerId: owner, local: MemoryLocal([record]));
    await controller.refresh();
    await tester.pumpWidget(ProviderScope(
      overrides: [inspectionControllerProvider.overrideWith((ref) => controller)],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Builder(builder: (context) => Scaffold(
          body: SingleChildScrollView(child: MapInspectionCard(
            marker: TreeMapModel(record),
            onClose: () {},
            onPrevious: () {},
            onNext: () {},
            onDetail: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SavedInspectionDetailScreen(record: record),
            )),
          )),
        )),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lihat detail inspeksi'));
    await tester.pumpAndSettle();
    expect(find.text('Detail inspeksi'), findsOneWidget);
    expect(find.text(record.data.treeSpecies), findsOneWidget);
    await tester.scrollUntilVisible(find.text(record.data.locationAddress), 240,
      scrollable: find.descendant(of: find.byType(SavedInspectionDetailScreen),
        matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text(record.data.locationAddress), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
