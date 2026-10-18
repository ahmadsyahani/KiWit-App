import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/scan_analyzer.dart';
import '../../data/services/scan_camera.dart';
import '../../domain/models/inspection_location.dart';
import '../../domain/models/inspection_result_data.dart';
import '../../../../core/services/onnx_service.dart';

enum ScanStage { loading, ready, capturing, analyzing, locating, paused, error, completed }

/// Serializes native camera operations and rejects results from an old lifecycle.
class ScanController extends ChangeNotifier {
  ScanController({
    required this.camera,
    required this.analyzer,
    required this.locationLoader,
    InspectionLocation? selectedLocation,
    DateTime Function()? now,
    this.locationWaitTimeout = const Duration(seconds: 10),
  }) : location = selectedLocation?.isValid == true ? selectedLocation : null,
       _now = now ?? DateTime.now;

  final ScanCamera camera;
  final ScanAnalyzer analyzer;
  final Future<InspectionLocation?> Function() locationLoader;
  final DateTime Function() _now;
  final Duration locationWaitTimeout;
  ScanStage stage = ScanStage.loading;
  InspectionLocation? location;
  String? notice;
  bool settingsRequired = false;
  bool cameraReady = false;
  bool locationPending = false;
  bool _locationStarted = false;
  bool _active = true;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _cameraTail = Future.value();
  Future<void>? _analysisDone;
  Future<void>? _locationTask;

  bool get canCapture => stage == ScanStage.ready && _active && !_disposed;
  bool get busy => stage == ScanStage.capturing || stage == ScanStage.analyzing ||
      stage == ScanStage.locating;
  bool _current(int token) => !_disposed && _active && token == _generation;

  Future<T> _cameraOperation<T>(Future<T> Function() operation) {
    final next = _cameraTail.then((_) => operation());
    _cameraTail = next.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return next;
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed || !_active) return;
    final token = ++_generation;
    stage = ScanStage.loading;
    cameraReady = false;
    notice = null;
    settingsRequired = false;
    _changed();
    try {
      await _cameraOperation(camera.open);
      if (!_current(token)) return;
      cameraReady = true;
      _changed();
      // Camera permission is resolved before requesting location permission.
      unawaited(_locationTask ??= _loadLocation());
      await analyzer.prepare();
      await _analysisDone;
      if (!_current(token)) return;
      stage = ScanStage.ready;
      _changed();
    } catch (error, stack) {
      if (!_current(token)) return;
      debugPrint('Scan initialization: $error\n$stack');
      stage = ScanStage.error;
      notice = error is ScanCameraFailure
          ? error.message : 'Kamera atau pemrosesan foto belum siap. Coba lagi.';
      settingsRequired = error is ScanCameraFailure && error.settingsRequired;
      _changed();
    }
  }

  Future<void> _loadLocation() async {
    if (_locationStarted || location != null) return;
    _locationStarted = true;
    locationPending = true;
    _changed();
    try {
      final resolved = await locationLoader();
      if (!_disposed && resolved?.isValid == true) location = resolved;
    } catch (_) {
      // Missing location is explicit; it must not block taking a photo.
    } finally {
      locationPending = false;
      _changed();
    }
  }

  void setActive(bool value) {
    if (_disposed || _active == value) return;
    _active = value;
    if (value) {
      unawaited(start());
    } else {
      ++_generation;
      cameraReady = false;
      stage = ScanStage.paused;
      _changed();
      unawaited(_cameraOperation(camera.close).catchError((Object error) {
        debugPrint('Camera close: $error');
      }));
    }
  }

  Future<InspectionResultData?> capture() async {
    if (!canCapture) return null;
    final token = _generation;
    final capturedAt = _now();
    final capturedLocation = location;
    stage = ScanStage.capturing;
    notice = null;
    _changed();
    try {
      final path = await _cameraOperation(camera.capture);
      if (!_current(token)) return null;
      stage = ScanStage.analyzing;
      _changed();
      final completion = Completer<void>();
      _analysisDone = completion.future;
      YoloSegmentationResult? result;
      try {
        result = await analyzer.analyze(path);
      } finally {
        completion.complete();
      }
      if (!_current(token)) return null;
      if (result == null || !result.isValidTree) {
        notice = 'Batang pohon belum dikenali dengan cukup jelas. Foto belum bisa dilaporkan. Arahkan kamera ke kulit batang pohon, lalu ambil ulang dengan cahaya cukup dan fokus.';
        stage = ScanStage.ready;
        _changed();
        return null;
      }
      // Give a GPS request started before the photo time to finish. Never wait
      // indefinitely, and never replace the location that was ready at capture.
      if (capturedLocation == null && locationPending) {
        stage = ScanStage.locating;
        _changed();
        await _locationTask?.timeout(locationWaitTimeout, onTimeout: () {});
        if (!_current(token)) return null;
      }
      final resultLocation = capturedLocation ?? location;
      final data = InspectionResultData(
        imagePath: path,
        healthScore: (100 - result.persentaseLuka).round().clamp(10, 98),
        riskStatus: result.riskDecision.riskStatus,
        ronggaBatang: result.persentaseLuka,
        // Existing estimates remain pending field calibration; see docs/scan-flow.md.
        sudutKemiringan: double.parse(
          (result.maxConfidenceRough * 18 + result.maxConfidenceCanker * 15 + 2)
              .clamp(1.5, 38.0).toStringAsFixed(1)),
        diameter: result.estimatedDbhCm,
        isJamurPelapuk: result.isJamurPelapuk,
        inspectionId: const Uuid().v4(),
        treeSpecies: 'Belum ditentukan',
        detectedCondition: result.detectedCondition,
        locationAddress: resultLocation?.label ?? 'Lokasi belum tersedia',
        scanTimestamp: capturedAt,
        latitude: resultLocation?.latitude,
        longitude: resultLocation?.longitude,
        persentaseLuka: result.persentaseLuka,
        failurePotential: result.failurePotential.label,
        environmentalImpact: EnvironmentalImpact.medium.label,
        riskAction: result.riskDecision.actionTitle,
        healthyPixelCount: result.healthyPixels,
        defectPixelCount: result.defectPixels,
      );
      stage = ScanStage.completed;
      _changed();
      return data;
    } catch (error, stack) {
      if (!_current(token)) return null;
      debugPrint('Photo capture/analysis: $error\n$stack');
      notice = stage == ScanStage.capturing
          ? 'Foto belum berhasil diambil. Coba tekan tombol foto lagi.'
          : 'Foto belum berhasil dianalisis. Coba ambil ulang dengan pencahayaan yang cukup.';
      stage = ScanStage.ready;
      _changed();
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_cameraOperation(camera.close).catchError((Object error) {
      debugPrint('Camera disposal: $error');
    }));
    super.dispose();
  }
}
