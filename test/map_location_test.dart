import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/features/map/data/services/map_location_service.dart';
import 'package:kiwit_app/features/map/presentation/screens/map_screen.dart';
import 'package:kiwit_app/features/map/presentation/widgets/user_location_marker.dart';
import 'package:kiwit_app/features/scan/data/models/saved_inspection.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';

import 'inspection_sync_test.dart' show MemoryLocal, owner;
import 'map_data_flow_test.dart' show MemoryTiles, inspection;

Future<void> frames(WidgetTester tester) async {
  // The location marker has a repeating animation, so pumpAndSettle is unsuitable.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<InspectionController> openMap(
  WidgetTester tester,
  Future<LatLng> Function() loader, {
  List<SavedInspection> records = const [],
}) async {
  final source = InspectionController(ownerId: owner, local: MemoryLocal(records));
  await source.refresh();
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserIdProvider.overrideWithValue(owner),
    inspectionControllerProvider.overrideWith((ref) => source),
  ], child: MaterialApp(home: MapScreen(
    tileProvider: MemoryTiles(), locationLoader: loader,
  ))));
  await frames(tester);
  return source;
}

MapController map(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

void main() {
  const device = LatLng(-6.1754, 106.8272);

  testWidgets('opening map focuses device instead of stored inspection points', (tester) async {
    var requests = 0;
    final source = await openMap(tester, () async {
      requests++;
      return device;
    }, records: [inspection('surabaya')]);
    expect(requests, 1);
    expect(map(tester).camera.zoom, 17);
    expect(map(tester).camera.center.latitude, closeTo(device.latitude, .01));
    expect(map(tester).camera.center.longitude, closeTo(device.longitude, .01));
    expect(find.byType(UserLocationPingMarker), findsOneWidget);
    final before = map(tester).camera.center;
    await source.save(data: inspection('late').data,
      notes: '', inspectorName: 'Petugas', rayon: 'Rayon 3');
    await frames(tester);
    expect(map(tester).camera.center, before);
    expect(requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('slow initial GPS takes priority over inspection auto fit', (tester) async {
    final gps = Completer<LatLng>();
    await openMap(tester, () => gps.future, records: [inspection('saved')]);
    expect(map(tester).camera.zoom, 4);
    gps.complete(device);
    await frames(tester);
    expect(map(tester).camera.center.latitude, closeTo(device.latitude, .01));
    expect(map(tester).camera.zoom, 17);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late GPS never undoes a map gesture', (tester) async {
    final gps = Completer<LatLng>();
    await openMap(tester, () => gps.future, records: [inspection('saved')]);
    final surface = find.byType(FlutterMap);
    await tester.dragFrom(tester.getCenter(surface), const Offset(-100, 70));
    await frames(tester);
    final before = map(tester).camera.center;
    gps.complete(device);
    await frames(tester);
    expect(map(tester).camera.center, before);
    expect(find.byType(UserLocationPingMarker), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('GPS failure falls back to saved points and explicit retry works', (tester) async {
    var requests = 0;
    await openMap(tester, () async {
      if (++requests == 1) throw const FormatException('Aktifkan GPS');
      return device;
    }, records: [inspection('saved')]);
    expect(map(tester).camera.center.latitude, closeTo(-7.25, .01));
    expect(find.byType(UserLocationPingMarker), findsNothing);
    expect(find.text('Aktifkan GPS'), findsOneWidget);
    await tester.tap(find.byTooltip('Lokasi saya'));
    await frames(tester);
    expect(requests, 2);
    expect(map(tester).camera.center.latitude, closeTo(device.latitude, .01));
    expect(find.byType(UserLocationPingMarker), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no GPS or records keeps a neutral overview without a false marker', (tester) async {
    final source = await openMap(tester, () async =>
      throw const FormatException('Izin lokasi belum diberikan'));
    expect(map(tester).camera.zoom, 4);
    expect(map(tester).camera.center, const LatLng(-2.5, 118));
    expect(find.byType(UserLocationPingMarker), findsNothing);
    await source.save(data: inspection('arrived-later').data,
      notes: '', inspectorName: 'Petugas', rayon: 'Rayon 3');
    await frames(tester);
    expect(map(tester).camera.center.latitude, closeTo(-7.25, .01));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('GPS response after map disposal is ignored', (tester) async {
    final gps = Completer<LatLng>();
    await openMap(tester, () => gps.future);
    await tester.pumpWidget(const SizedBox());
    gps.complete(device);
    await frames(tester);
    expect(tester.takeException(), isNull);
  });

  group('device GPS permission flow', () {
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    final calls = <String>[];
    var enabled = true;
    var permission = 0;
    var granted = 2;

    setUp(() {
      calls.clear();
      enabled = true;
      permission = 0;
      granted = 2;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'isLocationServiceEnabled' => enabled,
          'checkPermission' => permission,
          'requestPermission' => granted,
          'getCurrentPosition' => <String, Object>{
            'latitude': device.latitude, 'longitude': device.longitude,
            'timestamp': DateTime(2026, 10, 18).millisecondsSinceEpoch,
          },
          _ => throw MissingPluginException(),
        };
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));

    test('first use requests permission and obtains a current GPS fix', () async {
      final point = await resolveMapLocation();
      expect(point, device);
      expect(calls, ['isLocationServiceEnabled', 'checkPermission',
        'requestPermission', 'getCurrentPosition']);
    });

    test('existing permission does not trigger another permission dialog', () async {
      permission = 2;
      expect(await resolveMapLocation(), device);
      expect(calls, isNot(contains('requestPermission')));
    });

    test('disabled GPS returns recovery guidance without reading coordinates', () async {
      enabled = false;
      await expectLater(resolveMapLocation(), throwsA(isA<FormatException>()));
      expect(calls, ['isLocationServiceEnabled']);
    });

    test('denied permission never fetches or fabricates coordinates', () async {
      granted = 0;
      await expectLater(resolveMapLocation(), throwsA(isA<FormatException>()));
      expect(calls, isNot(contains('getCurrentPosition')));
    });

    test('permanent denial points to settings without requesting again', () async {
      permission = 1;
      await expectLater(resolveMapLocation(), throwsA(isA<FormatException>()));
      expect(calls, isNot(contains('requestPermission')));
      expect(calls, isNot(contains('getCurrentPosition')));
    });
  });
}
