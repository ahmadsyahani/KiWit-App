import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/scan_analyzer.dart';
import '../../data/services/scan_camera.dart';
import '../../domain/models/inspection_location.dart';
import '../../domain/models/inspection_result_data.dart';
import '../../../../core/services/onnx_service.dart';

enum ScanStage {
  loading,
  ready,
  capturing,
  analyzing,
  locating,
  paused,
  error,
  completed,
}

/// Serializes native camera operations and rejects results from an old lifecycle.
class ScanController extends ChangeNotifier {
  ScanController({
    required this.camera,
    required this.analyzer,
    required this.locationLoader,
    InspectionLocation? selectedLocation,
    DateTime Function()? now,
    this.locationWaitTimeout = const Duration(seconds: 10),
    this.locationMaxAge = const Duration(seconds: 30),
  }) : location = selectedLocation?.isValid == true ? selectedLocation : null,
       _fixedLocation = selectedLocation?.isValid == true,
       _now = now ?? DateTime.now;

  final ScanCamera camera;
  final ScanAnalyzer analyzer;
  final Future<InspectionLocation?> Function() locationLoader;
  final DateTime Function() _now;
  final Duration locationWaitTimeout;
  final Duration locationMaxAge;
  final bool _fixedLocation;
  DateTime? _locationResolvedAt;
  ScanStage stage = ScanStage.loading;
  InspectionLocation? location;
  String? notice;
  bool settingsRequired = false;
  bool cameraReady = false;
  bool locationPending = false;
  bool _active = true;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _cameraTail = Future.value();
  Future<void>? _analysisDone;
  Future<void>? _locationTask;

  bool get canCapture => stage == ScanStage.ready && _active && !_disposed;
  bool get busy =>
      stage == ScanStage.capturing ||
      stage == ScanStage.analyzing ||
      stage == ScanStage.locating;
  bool _current(int token) => !_disposed && _active && token == _generation;

  Future<T> _cameraOperation<T>(Future<T> Function() operation) {
    final next = _cameraTail.then((_) => operation());
    _cameraTail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
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
      unawaited(_ensureLocation(force: true));
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
          ? error.message
          : 'Kamera atau pemrosesan foto belum siap. Coba lagi.';
      settingsRequired = error is ScanCameraFailure && error.settingsRequired;
      _changed();
    }
  }

  Future<void> _ensureLocation({bool force = false}) {
    if (_fixedLocation || _disposed) return Future.value();
    if (_locationTask != null) return _locationTask!;
    final age = _locationResolvedAt == null
        ? null
        : _now().difference(_locationResolvedAt!);
    if (!force &&
        location != null &&
        age != null &&
        !age.isNegative &&
        age < locationMaxAge) {
      return Future.value();
    }
    // Never silently attach a known stale fix if the fresh request fails.
    location = null;
    _locationResolvedAt = null;
    late final Future<void> task;
    task = _loadLocation().whenComplete(() {
      if (identical(_locationTask, task)) _locationTask = null;
    });
    _locationTask = task;
    return task;
  }

  Future<void> _loadLocation() async {
    locationPending = true;
    _changed();
    try {
      final resolved = await locationLoader();
      if (!_disposed && resolved?.isValid == true) {
        location = resolved;
        _locationResolvedAt = _now();
      }
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
      unawaited(
        _cameraOperation(camera.close).catchError((Object error) {
          debugPrint('Camera close: $error');
        }),
      );
    }
  }

  Future<InspectionResultData?> capture() async {
    if (!canCapture) return null;
    final token = _generation;
    final capturedAt = _now();
    unawaited(_ensureLocation());
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
      } on BarkAnalysisRejected catch (error) {
        // Object/confidence filtering must not block capturing an inspection.
        // Malformed model data remains a technical failure, not an assessment.
        if (error.reason == BarkRejectionReason.invalidOutput) rethrow;
        result = null;
      } finally {
        completion.complete();
      }
      if (!_current(token)) return null;
      if (result?.isValidTree == false) result = null;
      // Give a GPS request started before the photo time to finish. Never wait
      // indefinitely, and never replace the location that was ready at capture.
      if (capturedLocation == null && locationPending) {
        stage = ScanStage.locating;
        _changed();
        await _locationTask?.timeout(locationWaitTimeout, onTimeout: () {});
        if (!_current(token)) return null;
      }
      final resultLocation = capturedLocation ?? location;
      final data = result == null
          ? InspectionResultData.unassessed(
              imagePath: path,
              inspectionId: const Uuid().v4(),
              locationAddress: resultLocation?.label ?? 'Lokasi belum tersedia',
              scanTimestamp: capturedAt,
              latitude: resultLocation?.latitude,
              longitude: resultLocation?.longitude,
            )
          : InspectionResultData(
              imagePath: path,
              healthScore: (100 - result.persentaseLuka).round().clamp(0, 100),
              riskStatus: result.riskDecision.riskStatus,
              ronggaBatang: result.persentaseLuka,
              // This model supplies no calibrated dimensions, inclination or fungus
              // diagnosis. These placeholders are hidden by the measurement flags.
              sudutKemiringan: 0,
              diameter: 0,
              isJamurPelapuk: false,
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
      notice = error is BarkAnalysisRejected
          ? switch (error.reason) {
              BarkRejectionReason.lowConfidence =>
                'Model belum cukup yakin mengenali kondisi kulit batang. Ini belum memastikan objek bukan pohon. Foto belum bisa dilaporkan. Foto batang asli dari dekat, termasuk bagian yang rusak.',
              BarkRejectionReason.insufficientMask =>
                'Area kulit batang belum terbaca cukup jelas. Foto belum bisa dilaporkan. Penuhi bingkai dengan batang dan bagian yang rusak, lalu ambil ulang dengan fokus.',
              BarkRejectionReason.invalidOutput =>
                'Hasil analisis belum dapat dibaca (kode ${error.diagnosticCode ?? "SCAN-00"}). Coba ulangi inspeksi. Jika tetap terjadi, laporkan kode ini.',
            }
          : stage == ScanStage.capturing
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
    unawaited(
      _cameraOperation(camera.close).catchError((Object error) {
        debugPrint('Camera disposal: $error');
      }),
    );
    super.dispose();
  }
}
