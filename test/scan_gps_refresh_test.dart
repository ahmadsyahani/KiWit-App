import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_location.dart';
import 'package:kiwit_app/features/scan/presentation/controllers/scan_controller.dart';
import 'scan_flow_test.dart' show FakeCamera, FakeAnalyzer;

void main() {
  const first = InspectionLocation(latitude: -7.28, longitude: 112.79);
  const next = InspectionLocation(latitude: -7.30, longitude: 112.81);

  test(
    'automatic GPS refreshes on resume, and expired fix refreshes again at capture',
    () async {
      var time = DateTime(2026, 10, 20);
      var calls = 0;
      final scan = ScanController(
        camera: FakeCamera(),
        analyzer: FakeAnalyzer(),
        now: () => time,
        locationLoader: () async => ++calls == 1 ? first : next,
      );
      addTearDown(scan.dispose);
      await scan.start();
      await Future<void>.delayed(Duration.zero);
      expect(scan.location, first);
      scan.setActive(false);
      scan.setActive(true);
      for (var i = 0; i < 20 && !scan.canCapture; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(scan.location, next);
      expect(calls, 2);
      time = time.add(const Duration(minutes: 2));
      final result = await scan.capture();
      expect(calls, 3);
      expect(result!.latitude, next.latitude);
      expect(result.longitude, next.longitude);
    },
  );

  test(
    'fresh capture fix is reused; failed refresh never falls back to stale coordinates',
    () async {
      var time = DateTime(2026);
      var calls = 0;
      final scan = ScanController(
        camera: FakeCamera(),
        analyzer: FakeAnalyzer(),
        now: () => time,
        locationLoader: () async => ++calls == 1 ? first : null,
      );
      addTearDown(scan.dispose);
      await scan.start();
      await Future<void>.delayed(Duration.zero);
      time = time.add(const Duration(minutes: 1));
      final result = await scan.capture();
      expect(calls, 2);
      expect(result!.latitude, isNull);
      expect(result.longitude, isNull);
      expect(result.locationAddress, 'Lokasi belum tersedia');
    },
  );

  test(
    'capture shares an in-flight GPS request rather than launching duplicates',
    () async {
      var calls = 0;
      final fix = Completer<InspectionLocation?>();
      final scan = ScanController(
        camera: FakeCamera(),
        analyzer: FakeAnalyzer(),
        locationLoader: () {
          calls++;
          return fix.future;
        },
      );
      addTearDown(scan.dispose);
      await scan.start();
      final result = scan.capture();
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      fix.complete(next);
      expect((await result)!.longitude, next.longitude);
    },
  );

  test(
    'a fixed selected location never requests or replaces its manual point',
    () async {
      var calls = 0;
      final scan = ScanController(
        camera: FakeCamera(),
        analyzer: FakeAnalyzer(),
        selectedLocation: first,
        locationLoader: () async {
          calls++;
          return next;
        },
      );
      addTearDown(scan.dispose);
      await scan.start();
      scan.setActive(false);
      scan.setActive(true);
      for (var i = 0; i < 20 && !scan.canCapture; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final result = await scan.capture();
      expect(calls, 0);
      expect(result!.latitude, first.latitude);
    },
  );
}
