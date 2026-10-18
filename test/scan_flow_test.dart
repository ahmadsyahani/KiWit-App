import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/services/onnx_service.dart';
import 'package:kiwit_app/features/scan/data/services/scan_analyzer.dart';
import 'package:kiwit_app/features/scan/data/services/scan_camera.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_location.dart';
import 'package:kiwit_app/features/scan/presentation/controllers/scan_controller.dart';
import 'package:kiwit_app/features/scan/presentation/screens/scan_screen.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_result_screen.dart';

class FakeCamera implements ScanCamera {
  final calls = <String>[];
  Completer<void>? opening;
  Completer<String>? capturing;
  Object? openError;
  Object? captureError;
  @override
  Future<void> open() async {
    calls.add('open');
    await opening?.future;
    if (openError != null) throw openError!;
  }
  @override
  Future<String> capture() async {
    calls.add('capture');
    if (captureError != null) throw captureError!;
    return capturing == null ? '/photo.jpg' : await capturing!.future;
  }
  @override
  Future<void> close() async { calls.add('close'); }
  @override
  Widget preview() => const ColoredBox(color: Colors.grey);
}

class FakeAnalyzer implements ScanAnalyzer {
  Object? prepareError;
  Object? analyzeError;
  Completer<YoloSegmentationResult?>? processing;
  bool reject = false;
  int calls = 0;
  @override
  Future<void> prepare() async {
    if (prepareError != null) throw prepareError!;
  }
  @override
  Future<YoloSegmentationResult?> analyze(String imagePath) async {
    calls++;
    if (analyzeError != null) throw analyzeError!;
    if (processing != null) return processing!.future;
    return reject ? null : segmentation();
  }
}

YoloSegmentationResult segmentation() => YoloSegmentationResult(
  isValidTree: true, healthyPixels: 80, defectPixels: 20, totalTrunkPixels: 100,
  persentaseLuka: 20, maxConfidenceRough: .3, maxConfidenceHealthy: .8,
  maxConfidenceCanker: .2, isJamurPelapuk: false, detectedCondition: 'Test',
  estimatedDbhCm: 40, failurePotential: FailurePotential.possible,
  riskDecision: IsaTraqEvaluator.evaluateMatrix(
    failurePotential: FailurePotential.possible,
    environmentalImpact: EnvironmentalImpact.medium),
);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeCamera camera;
  late FakeAnalyzer analyzer;
  late ScanController scan;
  const point = InspectionLocation(latitude: -7.28, longitude: 112.79, address: 'Titik pilihan');
  setUp(() {
    camera = FakeCamera();
    analyzer = FakeAnalyzer();
    scan = ScanController(camera: camera, analyzer: analyzer,
      locationLoader: () async => null);
  });
  tearDown(() { scan.dispose(); });

  test('capture disabled before preparation; permission failure supports retry', () async {
    expect(await scan.capture(), isNull);
    camera.openError = const ScanCameraFailure('Izin kamera', settingsRequired: true);
    await scan.start();
    expect(scan.stage, ScanStage.error);
    expect(scan.settingsRequired, isTrue);
    expect(camera.calls, ['open']);
    camera.openError = null;
    await scan.start();
    expect(scan.canCapture, isTrue);
    expect(scan.settingsRequired, isFalse);
  });

  test('model preparation failure does not enable shutter', () async {
    analyzer.prepareError = StateError('model missing');
    await scan.start();
    expect(scan.stage, ScanStage.error);
    expect(await scan.capture(), isNull);
    expect(analyzer.calls, 0);
    analyzer.prepareError = null;
    await scan.start();
    expect(scan.canCapture, isTrue);
  });

  test('fixed map location skips GPS and photo uses capture timestamp + UUID', () async {
    scan.dispose();
    var gpsCalls = 0;
    final timestamp = DateTime(2026, 10, 18, 10);
    scan = ScanController(camera: camera, analyzer: analyzer,
      selectedLocation: point, now: () => timestamp,
      locationLoader: () async { gpsCalls++; return null; });
    await scan.start();
    final result = await scan.capture();
    expect(gpsCalls, 0);
    expect(result!.latitude, point.latitude);
    expect(result.longitude, point.longitude);
    expect(result.locationAddress, point.label);
    expect(result.scanTimestamp, timestamp);
    expect(result.imagePath, '/photo.jpg');
    expect(result.inspectionId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(result.treeSpecies, 'Belum ditentukan');
    expect(await scan.capture(), isNull);
  });

  test('double shutter causes exactly one capture and analysis', () async {
    await scan.start();
    camera.capturing = Completer<String>();
    final first = scan.capture();
    expect(scan.stage, ScanStage.capturing);
    expect(await scan.capture(), isNull);
    await flush();
    camera.capturing!.complete('/photo.jpg');
    expect(await first, isNotNull);
    expect(camera.calls.where((c) => c == 'capture'), hasLength(1));
    expect(analyzer.calls, 1);
  });

  test('capture failure permits another attempt', () async {
    await scan.start();
    camera.captureError = StateError('capture failed');
    expect(await scan.capture(), isNull);
    expect(scan.canCapture, isTrue);
    expect(scan.notice, contains('diambil'));
    camera.captureError = null;
    expect(await scan.capture(), isNotNull);
  });

  test('analysis failure permits another attempt without fabricated result', () async {
    await scan.start();
    analyzer.analyzeError = StateError('inference failed');
    expect(await scan.capture(), isNull);
    expect(scan.canCapture, isTrue);
    expect(scan.notice, contains('dianalisis'));
    analyzer.analyzeError = null;
    expect(await scan.capture(), isNotNull);
  });

  test('unrecognized photo returns guidance and can be retaken', () async {
    await scan.start();
    analyzer.reject = true;
    expect(await scan.capture(), isNull);
    expect(scan.canCapture, isTrue);
    expect(scan.notice, contains('belum dikenali'));
    analyzer.reject = false;
    expect(await scan.capture(), isNotNull);
  });

  test('camera close waits for initialization; resume reopens in order', () async {
    camera.opening = Completer<void>();
    final starting = scan.start();
    await flush();
    scan.setActive(false);
    scan.setActive(true);
    expect(scan.canCapture, isFalse);
    expect(camera.calls, ['open']);
    camera.opening!.complete();
    await starting;
    await flush();
    expect(camera.calls, ['open', 'close', 'open']);
    expect(scan.canCapture, isTrue);
  });

  test('background during capture rejects photo and closes after capture', () async {
    await scan.start();
    camera.capturing = Completer<String>();
    final pending = scan.capture();
    await flush();
    scan.setActive(false);
    expect(camera.calls, ['open', 'capture']);
    camera.capturing!.complete('/photo.jpg');
    expect(await pending, isNull);
    await flush();
    expect(camera.calls.last, 'close');
    expect(analyzer.calls, 0);
    expect(scan.stage, ScanStage.paused);
  });

  test('resume waits for canceled analysis and never returns its stale result', () async {
    await scan.start();
    analyzer.processing = Completer<YoloSegmentationResult?>();
    final pending = scan.capture();
    await flush();
    expect(scan.stage, ScanStage.analyzing);
    scan.setActive(false);
    scan.setActive(true);
    await flush();
    expect(scan.canCapture, isFalse);
    analyzer.processing!.complete(segmentation());
    expect(await pending, isNull);
    await flush();
    expect(scan.canCapture, isTrue);
    analyzer.processing = null;
    expect(await scan.capture(), isNotNull);
    expect(analyzer.calls, 2);
  });

  test('location permission starts only after camera permission resolves', () async {
    scan.dispose();
    var gpsCalled = false;
    camera.opening = Completer<void>();
    scan = ScanController(camera: camera, analyzer: analyzer,
      locationLoader: () async { gpsCalled = true; return point; });
    final pending = scan.start();
    await flush();
    expect(gpsCalled, isFalse);
    camera.opening!.complete();
    await pending;
    expect(gpsCalled, isTrue);
    expect((await scan.capture())!.latitude, point.latitude);
  });

  test('unavailable GPS does not invent a location or block capture', () async {
    await scan.start();
    final result = await scan.capture();
    expect(result, isNotNull);
    expect(result!.latitude, isNull);
    expect(result.longitude, isNull);
    expect(result.locationAddress, 'Lokasi belum tersedia');
  });

  test('GPS completed during analysis is retained in the photo result', () async {
    scan.dispose();
    final gps = Completer<InspectionLocation?>();
    analyzer.processing = Completer<YoloSegmentationResult?>();
    scan = ScanController(camera: camera, analyzer: analyzer, locationLoader: () => gps.future);
    await scan.start();
    final pending = scan.capture();
    await flush();
    gps.complete(point);
    analyzer.processing!.complete(segmentation());
    final result = await pending;
    expect(result!.latitude, point.latitude);
    expect(result.longitude, point.longitude);
  });

  test('fast analysis waits for an already running GPS request', () async {
    scan.dispose();
    final gps = Completer<InspectionLocation?>();
    scan = ScanController(camera: camera, analyzer: analyzer, locationLoader: () => gps.future);
    await scan.start();
    final pending = scan.capture();
    await flush();
    expect(scan.stage, ScanStage.locating);
    expect(await scan.capture(), isNull);
    gps.complete(point);
    expect((await pending)!.latitude, point.latitude);
  });

  test('slow GPS has a bounded wait and cannot invent coordinates', () async {
    scan.dispose();
    final gps = Completer<InspectionLocation?>();
    scan = ScanController(camera: camera, analyzer: analyzer,
      locationLoader: () => gps.future, locationWaitTimeout: const Duration(milliseconds: 1));
    await scan.start();
    final result = await scan.capture();
    expect(result!.latitude, isNull);
    expect(result.locationAddress, 'Lokasi belum tersedia');
    gps.complete(point);
    await flush();
    expect(result.latitude, isNull);
  });

  test('background while waiting for GPS suppresses the stale result', () async {
    scan.dispose();
    final gps = Completer<InspectionLocation?>();
    scan = ScanController(camera: camera, analyzer: analyzer, locationLoader: () => gps.future);
    await scan.start();
    final pending = scan.capture();
    await flush();
    expect(scan.stage, ScanStage.locating);
    scan.setActive(false);
    gps.complete(point);
    expect(await pending, isNull);
    expect(scan.stage, ScanStage.paused);
  });

  testWidgets('compact camera UI has no technical/sample actions and shutter works',
    (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // This screen owns/disposes its injected controller; use a separate fixture.
      final ui = ScanController(camera: camera, analyzer: analyzer,
        locationLoader: () async => null);
      await tester.pumpWidget(MaterialApp(home: ScanScreen(controller: ui)));
      await tester.pumpAndSettle();
      expect(find.text('Inspeksi pohon'), findsOneWidget);
      expect(find.textContaining('YOLO'), findsNothing);
      expect(find.textContaining('ONNX'), findsNothing);
      expect(find.textContaining('Sampel'), findsNothing);
      expect(tester.takeException(), isNull);
      camera.captureError = StateError('device failure');
      await tester.tap(find.byTooltip('Ambil foto'));
      await tester.pumpAndSettle();
      expect(camera.calls, contains('capture'));
      expect(ui.notice, contains('diambil'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

  testWidgets('leaving camera while analyzing cannot navigate to a late result', (tester) async {
    final ui = ScanController(camera: camera, analyzer: analyzer,
      locationLoader: () async => null);
    analyzer.processing = Completer<YoloSegmentationResult?>();
    await tester.pumpWidget(MaterialApp(home: ScanScreen(controller: ui)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ambil foto'));
    await tester.pump();
    expect(ui.stage, ScanStage.analyzing);
    await tester.pumpWidget(const MaterialApp(home: Text('Closed')));
    analyzer.processing!.complete(segmentation());
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejected object stays on camera without a report or save action', (tester) async {
    analyzer.reject = true;
    final ui = ScanController(camera: camera, analyzer: analyzer,
      locationLoader: () async => null);
    await tester.pumpWidget(MaterialApp(home: ScanScreen(controller: ui)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ambil foto'));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byType(InspectionResultScreen), findsNothing);
    expect(ui.notice, contains('Foto belum bisa dilaporkan'));
    expect(ui.canCapture, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('result shows UUID without overflow; retake preserves map point', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Deny the native request deterministically; this test never opens a sensor.
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async =>
        call.method == 'requestPermissions' ? <int, int>{1: 0} : 0);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
    final resultFlow = ScanController(camera: FakeCamera(), analyzer: FakeAnalyzer(),
      locationLoader: () async => null);
    unawaited(resultFlow.start());
    await tester.pump();
    final capturing = resultFlow.capture();
    await tester.pump();
    final data = (await capturing)!.copyWith(
      latitude: point.latitude, longitude: point.longitude, locationAddress: point.label);
    resultFlow.dispose();
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      home: InspectionResultScreen(data: data))));
    await tester.pumpAndSettle();
    expect(find.text('ID #${data.inspectionId.substring(0, 8).toUpperCase()}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Foto Ulang'));
    await tester.pumpAndSettle();
    final retake = tester.widget<ScanScreen>(find.byType(ScanScreen));
    expect(retake.selectedLocation!.latitude, point.latitude);
    expect(retake.selectedLocation!.longitude, point.longitude);
    expect(retake.selectedLocation!.address, point.label);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
