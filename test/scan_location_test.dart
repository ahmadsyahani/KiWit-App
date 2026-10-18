import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/features/map/presentation/screens/map_screen.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_location.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_location_editor.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_location_picker.dart';
import 'package:kiwit_app/features/scan/presentation/screens/scan_screen.dart';
import 'inspection_sync_test.dart' show MemoryLocal, owner;
import 'map_data_flow_test.dart' show MemoryTiles;

void main() {
  testWidgets('new inspection from map opens camera without selecting a point', (tester) async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async =>
        call.method == 'requestPermissions' ? <int, int>{1: 0} : 0);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
    final source = InspectionController(ownerId: owner, local: MemoryLocal());
    await source.refresh();
    await tester.pumpWidget(ProviderScope(overrides: [
      currentUserIdProvider.overrideWithValue(owner),
      inspectionControllerProvider.overrideWith((ref) => source),
    ], child: MaterialApp(home: MapScreen(tileProvider: MemoryTiles()))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inspeksi baru'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(tester.widget<ScanScreen>(find.byType(ScanScreen)).selectedLocation, isNull);
    expect(find.text('Pilih lokasi pohon'), findsNothing);
    expect(find.text('Lanjut ke kamera'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('location editor retries GPS and returns coordinates with optional address', (tester) async {
    final gps = Completer<InspectionLocation?>();
    InspectionLocationEdit? edit;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        edit = await showModalBottomSheet<InspectionLocationEdit>(
          context: context, isScrollControlled: true,
          builder: (_) => InspectionLocationEditor(
            initialAddress: 'Lokasi belum tersedia', locationLoader: () => gps.future));
      }, child: const Text('Koreksi')),
    ))));
    await tester.tap(find.text('Koreksi'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    await tester.tap(find.text('Coba GPS lagi'));
    await tester.pump();
    expect(find.text('Mencari lokasi…'), findsOneWidget);
    gps.complete(const InspectionLocation(latitude: -7.28, longitude: 112.79, address: 'Jalan Kenanga'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sisi utara taman');
    await tester.tap(find.text('Simpan lokasi'));
    await tester.pumpAndSettle();
    expect(edit!.point!.latitude, -7.28);
    expect(edit!.point!.longitude, 112.79);
    expect(edit!.address, 'Sisi utara taman');
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed GPS explains recovery and does not fabricate a location', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: InspectionLocationEditor(locationLoader: () async => null))));
    await tester.tap(find.text('Coba GPS lagi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GPS belum tersedia.'), findsOneWidget);
    expect(find.text('Pilih di peta'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Simpan lokasi')).onPressed, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manual picker requires an explicit point when GPS has no coordinates', (tester) async {
    InspectionLocation? selected;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        selected = await Navigator.push<InspectionLocation>(context, MaterialPageRoute(
          builder: (_) => InspectionLocationPicker(tileProvider: MemoryTiles())));
      }, child: const Text('Koreksi')),
    ))));
    await tester.tap(find.text('Koreksi'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Gunakan lokasi ini')).onPressed, isNull);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan lokasi ini'));
    await tester.pumpAndSettle();
    expect(selected!.isValid, isTrue);
    expect(tester.takeException(), isNull);
  });
}
