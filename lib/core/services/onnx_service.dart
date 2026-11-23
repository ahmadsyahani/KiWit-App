import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../constants/app_colors.dart';
import '../widgets/risk_badge.dart';

/// Legacy storage categories used by the preliminary photo screening heuristic.
enum FailurePotential {
  improbable('Improbable', 'Area pola kerusakan pada foto kurang dari 10%'),
  possible('Possible', 'Area pola kerusakan pada foto 10–30%'),
  probable('Probable', 'Area pola kerusakan pada foto lebih dari 30%'),
  imminent('Imminent', 'Area pola kerusakan pada foto lebih dari 50%');

  final String label;
  final String description;
  const FailurePotential(this.label, this.description);

  static FailurePotential fromString(String val) {
    return FailurePotential.values.firstWhere(
      (e) => e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => FailurePotential.improbable,
    );
  }
}

/// Context selected by the inspector for preliminary follow-up prioritization.
enum EnvironmentalImpact {
  low('Low', 'Lahan kosong / Hutan lebat'),
  medium('Medium', 'Taman / Area jarang dilewati'),
  high('High', 'Jalan raya ramai / Fasilitas umum');

  final String label;
  final String description;
  const EnvironmentalImpact(this.label, this.description);

  static EnvironmentalImpact fromString(String val) {
    return EnvironmentalImpact.values.firstWhere(
      (e) => e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => EnvironmentalImpact.medium,
    );
  }
}

/// Preliminary photo-screening priority, not a structural safety diagnosis.
class IsaRiskDecision {
  final RiskLevel riskLevel;
  final String riskStatus; // 'Rendah', 'Sedang', 'Tinggi', 'Kritis'
  final String actionTitle;
  final String displayText;
  final Color statusColor;

  const IsaRiskDecision({
    required this.riskLevel,
    required this.riskStatus,
    required this.actionTitle,
    required this.displayText,
    required this.statusColor,
  });
}

/// Legacy class name retained for payload/caller compatibility.
class IsaTraqEvaluator {
  /// Consistent follow-up for a risk explicitly chosen by an officer.
  static IsaRiskDecision decisionForOfficerRisk(String status) {
    final failure = switch (status) {
      'Rendah' => FailurePotential.improbable,
      'Sedang' => FailurePotential.possible,
      'Tinggi' => FailurePotential.probable,
      'Kritis' => FailurePotential.imminent,
      _ => throw ArgumentError.value(status, 'status', 'Risiko tidak valid'),
    };
    return evaluateMatrix(
      failurePotential: failure,
      environmentalImpact: EnvironmentalImpact.medium,
    );
  }

  /// Preliminary photo-area screening, not a validated ISA TRAQ assessment.
  /// DBH is retained in the signature for old callers but never inferred from
  /// pixels or used to change this photo-only category.
  static FailurePotential evaluateFailurePotential(
    double persentaseLuka,
    double dbhCm,
  ) {
    if (persentaseLuka > 50.0) {
      return FailurePotential.imminent;
    } else if (persentaseLuka > 30.0) {
      return FailurePotential.probable;
    } else if (persentaseLuka >= 10.0 && persentaseLuka <= 30.0) {
      return FailurePotential.possible;
    } else {
      return FailurePotential.improbable;
    }
  }

  /// App-specific screening heuristic. These categories are not validated
  /// probabilities of failure and must not be presented as ISA certification.
  static IsaRiskDecision evaluateMatrix({
    required FailurePotential failurePotential,
    required EnvironmentalImpact environmentalImpact,
  }) {
    // Preserve category ordering while using follow-up recommendations only.
    switch (failurePotential) {
      case FailurePotential.improbable:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
          case EnvironmentalImpact.medium:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.rendah,
              riskStatus: 'Rendah',
              actionTitle: 'Pantau kondisi',
              displayText: 'PRIORITAS RENDAH (Pantau kondisi)',
              statusColor: AppColors.riskLowText,
            );
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.sedang,
              riskStatus: 'Sedang',
              actionTitle: 'Perlu Dipantau',
              displayText: 'PRIORITAS SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
        }

      case FailurePotential.possible:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.rendah,
              riskStatus: 'Rendah',
              actionTitle: 'Pantau kondisi',
              displayText: 'PRIORITAS RENDAH (Pantau kondisi)',
              statusColor: AppColors.riskLowText,
            );
          case EnvironmentalImpact.medium:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.sedang,
              riskStatus: 'Sedang',
              actionTitle: 'Perlu Dipantau',
              displayText: 'PRIORITAS SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.tinggi,
              riskStatus: 'Tinggi',
              actionTitle: 'Tindak Lanjuti',
              displayText: 'PRIORITAS TINGGI (Tindak Lanjuti)',
              statusColor: AppColors.riskHighText,
            );
        }

      case FailurePotential.probable:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.sedang,
              riskStatus: 'Sedang',
              actionTitle: 'Perlu Dipantau',
              displayText: 'PRIORITAS SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
          case EnvironmentalImpact.medium:
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.tinggi,
              riskStatus: 'Tinggi',
              actionTitle: 'Tindak Lanjuti',
              displayText: 'PRIORITAS TINGGI (Tindak Lanjuti)',
              statusColor: AppColors.riskHighText,
            );
        }

      case FailurePotential.imminent:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.tinggi,
              riskStatus: 'Tinggi',
              actionTitle: 'Tindak Lanjuti',
              displayText: 'PRIORITAS TINGGI (Tindak Lanjuti)',
              statusColor: AppColors.riskHighText,
            );
          case EnvironmentalImpact.medium:
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.kritis,
              riskStatus: 'Kritis',
              actionTitle: 'Prioritaskan pemeriksaan lapangan',
              displayText: 'PRIORITAS KRITIS (Periksa di lapangan)',
              statusColor: AppColors.riskCriticalText,
            );
        }
    }
  }
}

/// Hasil inferensi YOLO11 Segmentation
class YoloSegmentationResult {
  /// Legacy flag for usable segmentation, not proof of tree/non-tree identity.
  final bool isValidTree;
  final int healthyPixels;
  final int defectPixels;
  final int totalTrunkPixels;
  final double persentaseLuka;
  final double maxConfidenceRough;
  final double maxConfidenceHealthy;
  final double maxConfidenceCanker;
  final bool isJamurPelapuk;
  final String detectedCondition;
  final double estimatedDbhCm;
  final FailurePotential failurePotential;
  final IsaRiskDecision riskDecision;

  YoloSegmentationResult({
    required this.isValidTree,
    required this.healthyPixels,
    required this.defectPixels,
    required this.totalTrunkPixels,
    required this.persentaseLuka,
    required this.maxConfidenceRough,
    required this.maxConfidenceHealthy,
    required this.maxConfidenceCanker,
    required this.isJamurPelapuk,
    required this.detectedCondition,
    required this.estimatedDbhCm,
    required this.failurePotential,
    required this.riskDecision,
  });
}

enum BarkRejectionReason { lowConfidence, insufficientMask, invalidOutput }

class BarkAnalysisRejected implements Exception {
  const BarkAnalysisRejected(this.reason, {this.diagnosticCode});
  final BarkRejectionReason reason;
  final String? diagnosticCode;
  @override
  String toString() =>
      'BarkAnalysisRejected: ${reason.name} ${diagnosticCode ?? ""}';
}

/// Layanan AI OnnxService untuk YOLO11 Segmentation & ISA TRAQ
class OnnxService {
  static final OnnxService _instance = OnnxService._internal();
  factory OnnxService() => _instance;
  OnnxService._internal();

  OrtSession? _session;
  OrtSession? get session => _session;

  bool _isInitialized = false;
  bool _environmentInitialized = false;
  bool get isInitialized => _isInitialized;

  String _inputName = 'images';

  /// Used by the background photo worker after the asset has been loaded.
  void initModelBytes(Uint8List bytes) {
    if (_isInitialized && _session != null) return;
    OrtEnv.instance.init();
    _environmentInitialized = true;
    final options = OrtSessionOptions();
    try {
      _session = OrtSession.fromBuffer(bytes, options);
      final inputs = _session!.inputNames;
      final outputs = _session!.outputNames;
      if (inputs.isEmpty || outputs.length < 2) {
        throw StateError(
          'Model segmentasi tidak memiliki input/output yang sesuai.',
        );
      }
      _inputName = inputs.first;
      _isInitialized = true;
    } catch (_) {
      _session?.release();
      _session = null;
      _isInitialized = false;
      rethrow;
    } finally {
      options.release();
    }
  }

  Future<void> initModel() async {
    if (_isInitialized && _session != null) return;
    final raw = await rootBundle.load('assets/models/best.onnx');
    initModelBytes(
      raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes),
    );
  }

  /// Mengubah gambar ke input tensor Float32List NCHW [1, 3, 640, 640] ter-normalisasi [0, 1]
  Float32List imageToFloat32List(
    img.Image image, {
    int targetSize = 640,
    bool preserveAspectRatio = false,
  }) {
    // Roboflow dataset v2 explicitly uses 640x640 Stretch. Match that input
    // distribution in production; letterbox remains available for audit only.
    final bounds = preserveAspectRatio
        ? _letterboxBounds(image, targetSize)
        : Rect.fromLTWH(0, 0, targetSize.toDouble(), targetSize.toDouble());
    final scaledImage = img.copyResize(
      image,
      width: bounds.width.toInt(),
      height: bounds.height.toInt(),
      interpolation: img.Interpolation.linear,
    );
    // Padding is only present when an audit explicitly requests letterboxing.
    final resizedImage = img.Image(width: targetSize, height: targetSize);
    img.fill(resizedImage, color: img.ColorRgb8(114, 114, 114));
    img.compositeImage(
      resizedImage,
      scaledImage,
      dstX: bounds.left.toInt(),
      dstY: bounds.top.toInt(),
    );
    final Float32List float32list = Float32List(
      1 * 3 * targetSize * targetSize,
    );

    int pixelIndex = 0;
    final int planeSize = targetSize * targetSize;

    for (int y = 0; y < targetSize; y++) {
      for (int x = 0; x < targetSize; x++) {
        final pixel = resizedImage.getPixel(x, y);

        float32list[pixelIndex] = pixel.r / 255.0;
        float32list[planeSize + pixelIndex] = pixel.g / 255.0;
        float32list[2 * planeSize + pixelIndex] = pixel.b / 255.0;

        pixelIndex++;
      }
    }
    return float32list;
  }

  Rect _letterboxBounds(img.Image image, int size) {
    final scale = min(size / image.width, size / image.height);
    final width = (image.width * scale).round().clamp(1, size);
    final height = (image.height * scale).round().clamp(1, size);
    return Rect.fromLTWH(
      ((size - width) / 2).floorToDouble(),
      ((size - height) / 2).floorToDouble(),
      width.toDouble(),
      height.toDouble(),
    );
  }

  /// Eksekusi inferensi YOLO11-seg dan kalkulasi area piksel (Tahap 1, 2, 3)
  YoloSegmentationResult? runInference(
    img.Image image, {
    EnvironmentalImpact defaultImpact = EnvironmentalImpact.medium,
    void Function(BarkRejectionReason)? onRejected,
    void Function(String)? onInvalidOutput,
  }) {
    if (_session == null) {
      throw StateError('OnnxService belum diinisialisasi');
    }

    const int inputSize = 640;
    final inputData = imageToFloat32List(image, targetSize: inputSize);
    final inputTensor = OrtValueTensor.createTensorWithDataList(inputData, [
      1,
      3,
      inputSize,
      inputSize,
    ]);

    final runOptions = OrtRunOptions();
    final inputs = {_inputName: inputTensor};

    List<OrtValue?>? outputs;
    try {
      outputs = _session!.run(runOptions, inputs);
      if (outputs.isEmpty) {
        onRejected?.call(BarkRejectionReason.invalidOutput);
        onInvalidOutput?.call('SCAN-06');
        return null;
      }

      final out0Raw = outputs[0]?.value;
      dynamic out1Raw;
      if (outputs.length > 1) {
        out1Raw = outputs[1]?.value;
      }
      if (kDebugMode) {
        List<int> shapeOf(dynamic value) {
          final shape = <int>[];
          while (value is List && shape.length < 5) {
            shape.add(value.length);
            if (value.isEmpty) break;
            value = value.first;
          }
          return shape;
        }

        debugPrint(
          '[BarkScan] photo=${image.width}x${image.height} '
          'outputs=${_session!.outputNames} '
          'detectionShape=${shapeOf(out0Raw)} maskShape=${shapeOf(out1Raw)}',
        );
      }

      return processSegmentationOutputs(
        out0Raw: out0Raw,
        out1Raw: out1Raw,
        defaultImpact: defaultImpact,
        onRejected: onRejected,
        onInvalidOutput: onInvalidOutput,
      );
    } finally {
      inputTensor.release();
      runOptions.release();
      if (outputs != null) {
        for (final o in outputs) {
          o?.release();
        }
      }
    }
  }

  /// Post-processing: Ekstraksi Poligon Mask, Pixel Area Calculation & ISA TRAQ
  @visibleForTesting
  YoloSegmentationResult? processSegmentationOutputs({
    required dynamic out0Raw,
    required dynamic out1Raw,
    required EnvironmentalImpact defaultImpact,
    Rect inputBounds = const Rect.fromLTWH(0, 0, 640, 640),
    void Function(BarkRejectionReason)? onRejected,
    void Function(String)? onInvalidOutput,
  }) {
    double peakScore = 0;
    int candidateCount = 0;
    YoloSegmentationResult? reject(
      BarkRejectionReason reason, {
      String? code,
      String? detail,
    }) {
      onRejected?.call(reason);
      if (reason == BarkRejectionReason.invalidOutput) {
        onInvalidOutput?.call(code ?? 'SCAN-00');
      }
      if (kDebugMode) {
        debugPrint(
          '[BarkScan] rejected=${reason.name} '
          'code=${code ?? "-"} detail=${detail ?? "-"} '
          'peak=${peakScore.toStringAsFixed(3)} candidates=$candidateCount',
        );
      }
      return null;
    }

    if (!inputBounds.isFinite ||
        inputBounds.isEmpty ||
        inputBounds.left < 0 ||
        inputBounds.top < 0 ||
        inputBounds.right > 640 ||
        inputBounds.bottom > 640) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-01',
        detail: 'Invalid input content bounds: $inputBounds',
      );
    }
    final contentArea = inputBounds.width * inputBounds.height;
    final contentX1 = (inputBounds.left / 4).ceil();
    final contentY1 = (inputBounds.top / 4).ceil();
    final contentX2 = (inputBounds.right / 4).ceil() - 1;
    final contentY2 = (inputBounds.bottom / 4).ceil() - 1;
    final contentPixels =
        (contentX2 - contentX1 + 1) * (contentY2 - contentY1 + 1);
    if (out0Raw is! List || out0Raw.isEmpty) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-02',
        detail: 'Missing detection tensor (${out0Raw.runtimeType})',
      );
    }

    // out0 shape: [1, 39, 8400]
    final dynamic data2d = (out0Raw.length == 1 && out0Raw[0] is List)
        ? out0Raw[0]
        : out0Raw;

    // Require the complete segmentation output, not classification scores alone.
    if (data2d is! List || data2d.length != 39) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-02',
        detail:
            'Expected 39 detection channels, got ${data2d is List ? data2d.length : data2d.runtimeType}',
      );
    }
    if (data2d.any((row) => row is! List)) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-02',
        detail: 'Detection channels are not lists',
      );
    }
    final anchorCount = (data2d[0] as List).length;
    if (anchorCount == 0 ||
        data2d.any((row) => (row as List).length != anchorCount)) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-02',
        detail: 'Empty or unequal detection channel lengths',
      );
    }

    final rowCx = data2d[0] as List;
    final rowCy = data2d[1] as List;
    final rowW = data2d[2] as List;
    final rowH = data2d[3] as List;

    // Catatan Arsitektur:
    // best.onnx YOLO11n-seg memiliki kelas:
    // 0: Rough bark (Kulit kasar / terkelupas - luka)
    // 1: healthy bark (Kulit sehat)
    // 2: stripecanker (Luka kanker / jamur pelapuk)
    final rowC0 = data2d[4] as List; // Rough bark
    final rowC1 = data2d[5] as List; // healthy bark
    final rowC2 = data2d[6] as List; // stripecanker

    double maxRough = 0.0;
    double maxHealthy = 0.0;
    double maxCanker = 0.0;

    final int numAnchors = rowC0.length;

    // Ekstraksi deteksi dengan confidence threshold
    // Conservative provisional thresholds. These require field calibration;
    // confidence is not a guarantee that an unfamiliar object is a tree.
    const double confThreshold = 0.70;
    // Android float32 sigmoid kernels can return tiny boundary overshoots.
    // Observed on-device: -5.960464477539063e-8. Only absorb roundoff;
    // malformed/nonfinite probabilities must still fail closed.
    const double scoreTolerance = 1e-6;
    final List<_DetectionBox> detections = [];

    for (int i = 0; i < numAnchors; i++) {
      var sRough = (rowC0[i] as num).toDouble();
      var sHealthy = (rowC1[i] as num).toDouble();
      var sCanker = (rowC2[i] as num).toDouble();
      final w = (rowW[i] as num).toDouble();

      if (![sRough, sHealthy, sCanker].every(
        (score) =>
            score.isFinite &&
            score >= -scoreTolerance &&
            score <= 1 + scoreTolerance,
      )) {
        return reject(
          BarkRejectionReason.invalidOutput,
          code: 'SCAN-03',
          detail:
              'Invalid class scores at anchor $i: $sRough,$sHealthy,$sCanker',
        );
      }
      sRough = sRough.clamp(0.0, 1.0);
      sHealthy = sHealthy.clamp(0.0, 1.0);
      sCanker = sCanker.clamp(0.0, 1.0);

      int bestClass = 1; // Default healthy
      double maxScore = sHealthy;

      if (sRough > maxScore) {
        maxScore = sRough;
        bestClass = 0; // Rough bark (cacat)
      }
      if (sCanker > maxScore) {
        maxScore = sCanker;
        bestClass = 2; // Stripecanker (cacat)
      }
      peakScore = max(peakScore, maxScore);

      if (maxScore >= confThreshold) {
        final cx = (rowCx[i] as num).toDouble();
        final cy = (rowCy[i] as num).toDouble();
        final h = (rowH[i] as num).toDouble();
        if (![cx, cy, w, h].every((value) => value.isFinite) ||
            w <= 0 ||
            h <= 0) {
          continue;
        }
        final visibleW =
            (cx + w / 2).clamp(inputBounds.left, inputBounds.right) -
            (cx - w / 2).clamp(inputBounds.left, inputBounds.right);
        final visibleH =
            (cy + h / 2).clamp(inputBounds.top, inputBounds.bottom) -
            (cy - h / 2).clamp(inputBounds.top, inputBounds.bottom);
        if (visibleW * visibleH < contentArea * 0.04) continue;

        // 32 prototype mask coefficients (channels 7..38)
        final coeffs = List<double>.generate(
          32,
          (k) => ((data2d[7 + k] as List)[i] as num).toDouble(),
        );
        if (coeffs.any((value) => !value.isFinite)) continue;

        detections.add(
          _DetectionBox(
            classId: bestClass,
            score: maxScore,
            cx: cx,
            cy: cy,
            w: w,
            h: h,
            maskCoeffs: coeffs,
          ),
        );
      }
    }

    candidateCount = detections.length;
    // Missing bark evidence cannot establish that the object is not a tree.
    if (detections.isEmpty) {
      return reject(
        peakScore < confThreshold
            ? BarkRejectionReason.lowConfidence
            : BarkRejectionReason.insufficientMask,
      );
    }

    // -------------------------------------------------------------
    // Tahap 1: Ekstraksi Data (AI ke Angka) via Pixel Area Calculation
    // Rumus: Persentase Luka = (Total Area Piksel Cacat / Total Area Piksel Batang) * 100
    // -------------------------------------------------------------
    int defectPixels = 0;
    int healthyPixels = 0;

    // Jika out1 (prototype masks 32x160x160) tersedia
    final dynamic proto3d =
        (out1Raw is List && out1Raw.isNotEmpty && out1Raw[0] is List)
        ? out1Raw[0]
        : null;
    if (proto3d is! List ||
        proto3d.length != 32 ||
        proto3d.any(
          (plane) =>
              plane is! List ||
              plane.length != 160 ||
              plane.any((row) => row is! List || row.length != 160),
        )) {
      return reject(
        BarkRejectionReason.invalidOutput,
        code: 'SCAN-04',
        detail:
            'Expected prototype [1,32,160,160], received ${out1Raw.runtimeType}',
      );
    }

    {
      // Grid 160x160 (0: none, 1: other recognized bark, 2: canker-like).
      final Uint8List maskGrid = Uint8List(160 * 160);

      // Suppress repeated anchors for the same object before merging masks.
      final retained = <_DetectionBox>[];
      detections.sort((a, b) => b.score.compareTo(a.score));
      for (final det in detections) {
        if (!retained.any(
          (other) =>
              other.classId == det.classId &&
              other.intersectionOverUnion(det) > 0.5,
        )) {
          retained.add(det);
        }
      }
      for (final det in retained) {
        if (det.maskCoeffs == null) continue;
        final coeffs = det.maskCoeffs!;
        // Rough bark is a texture class, not evidence of disease by itself.
        final isDefect = det.classId == 2;
        final labelVal = isDefect ? 2 : 1;

        // Bounding box di grid 160x160 (downsample scale 4x dari 640x640)
        final int x1 = max(contentX1, ((det.cx - det.w / 2) / 4).floor());
        final int y1 = max(contentY1, ((det.cy - det.h / 2) / 4).floor());
        final int x2 = min(contentX2, ((det.cx + det.w / 2) / 4).floor());
        final int y2 = min(contentY2, ((det.cy + det.h / 2) / 4).floor());
        if (x2 < x1 || y2 < y1) continue;
        final pixels = <int>[];

        for (int y = y1; y <= y2; y++) {
          final int rowOffset = y * 160;
          for (int x = x1; x <= x2; x++) {
            double logit = 0.0;
            for (int k = 0; k < 32; k++) {
              final rowK = (proto3d[k] as List)[y] as List;
              logit += coeffs[k] * ((rowK[x] as num).toDouble());
            }
            if (!logit.isFinite) {
              return reject(
                BarkRejectionReason.invalidOutput,
                code: 'SCAN-05',
                detail: 'Nonfinite mask logit at $x,$y',
              );
            }

            // Sigmoid activation
            final double prob = 1.0 / (1.0 + exp(-logit));
            if (prob > 0.5) {
              pixels.add(rowOffset + x);
            }
          }
        }
        // A strong box without a substantial segmentation is insufficient.
        final boxPixels = (x2 - x1 + 1) * (y2 - y1 + 1);
        if (pixels.length < contentPixels * 0.03 ||
            pixels.length / boxPixels < 0.20) {
          continue;
        }
        for (final idx in pixels) {
          if (maskGrid[idx] < labelVal) maskGrid[idx] = labelVal;
        }
        if (det.classId == 0) maxRough = max(maxRough, det.score);
        if (det.classId == 1) maxHealthy = max(maxHealthy, det.score);
        if (det.classId == 2) maxCanker = max(maxCanker, det.score);
      }

      for (int i = 0; i < 160 * 160; i++) {
        if (maskGrid[i] == 2) {
          defectPixels++;
        } else if (maskGrid[i] == 1) {
          healthyPixels++;
        }
      }
    }

    final int totalTrunkPixels = defectPixels + healthyPixels;
    if (totalTrunkPixels < contentPixels * 0.03) {
      return reject(BarkRejectionReason.insufficientMask);
    }
    if (kDebugMode) {
      debugPrint(
        '[BarkScan] accepted pixels=$totalTrunkPixels peak=${peakScore.toStringAsFixed(3)}',
      );
    }
    double persentaseLuka = (defectPixels / totalTrunkPixels) * 100.0;

    persentaseLuka = double.parse(
      persentaseLuka.clamp(0.0, 100.0).toStringAsFixed(1),
    );

    // There is no distance/reference scale in this model's input. Zero is a
    // storage placeholder for "not measured", never a physical measurement.
    const double estimatedDbh = 0;

    // Diagnosa Patologi
    // None of the three training labels establishes wood-decay fungus.
    const bool isJamurPelapuk = false;
    String detectedCondition;
    if (maxCanker > 0.20) {
      detectedCondition = 'Pola kulit menyerupai canker';
    } else if (maxRough > 0.35) {
      detectedCondition = 'Pola kulit batang kasar';
    } else {
      detectedCondition = 'Pola kulit sesuai kelas sehat';
    }

    // -------------------------------------------------------------
    // Tahap 2: Matriks ISA TRAQ (Variabel A & Variabel B)
    // -------------------------------------------------------------
    final failurePotential = IsaTraqEvaluator.evaluateFailurePotential(
      persentaseLuka,
      estimatedDbh,
    );

    final riskDecision = IsaTraqEvaluator.evaluateMatrix(
      failurePotential: failurePotential,
      environmentalImpact: defaultImpact,
    );

    return YoloSegmentationResult(
      isValidTree: true,
      healthyPixels: healthyPixels,
      defectPixels: defectPixels,
      totalTrunkPixels: totalTrunkPixels,
      persentaseLuka: persentaseLuka,
      maxConfidenceRough: maxRough,
      maxConfidenceHealthy: maxHealthy,
      maxConfidenceCanker: maxCanker,
      isJamurPelapuk: isJamurPelapuk,
      detectedCondition: detectedCondition,
      estimatedDbhCm: estimatedDbh,
      failurePotential: failurePotential,
      riskDecision: riskDecision,
    );
  }

  void dispose() {
    _session?.release();
    _session = null;
    if (_environmentInitialized) {
      OrtEnv.instance.release();
      _environmentInitialized = false;
    }
    _isInitialized = false;
  }
}

class _DetectionBox {
  final int classId;
  final double score;
  final double cx, cy, w, h;
  final List<double>? maskCoeffs;

  double intersectionOverUnion(_DetectionBox other) {
    final left = max(cx - w / 2, other.cx - other.w / 2);
    final top = max(cy - h / 2, other.cy - other.h / 2);
    final right = min(cx + w / 2, other.cx + other.w / 2);
    final bottom = min(cy + h / 2, other.cy + other.h / 2);
    final overlap = max(0.0, right - left) * max(0.0, bottom - top);
    return overlap / (w * h + other.w * other.h - overlap);
  }

  _DetectionBox({
    required this.classId,
    required this.score,
    required this.cx,
    required this.cy,
    required this.w,
    required this.h,
    this.maskCoeffs,
  });
}
