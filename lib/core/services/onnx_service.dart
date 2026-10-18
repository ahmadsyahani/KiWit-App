import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../constants/app_colors.dart';
import '../widgets/risk_badge.dart';

/// ISA TRAQ Variabel A: Potensi Kegagalan Batang/Pohon
enum FailurePotential {
  improbable('Improbable', 'Kecil kemungkinan patah'),
  possible('Possible', 'Mungkin patah'),
  probable('Probable', 'Sangat mungkin patah'),
  imminent('Imminent', 'Pasti akan patah/tumbang');

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

/// ISA TRAQ Variabel B: Dampak Lingkungan (Input Manual Petugas)
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

/// Hasil Keputusan Akhir Matriks ISA TRAQ
class IsaRiskDecision {
  final RiskLevel riskLevel;
  final String riskStatus; // 'Rendah', 'Sedang', 'Tinggi', 'Kritis'
  final String actionTitle; // 'Aman', 'Perlu Dipantau', 'Tindak Lanjuti', 'Tebang Segera!'
  final String displayText; // e.g. 'RISIKO RENDAH (Aman)'
  final Color statusColor;

  const IsaRiskDecision({
    required this.riskLevel,
    required this.riskStatus,
    required this.actionTitle,
    required this.displayText,
    required this.statusColor,
  });
}

/// Evaluator Matriks Risiko ISA TRAQ
class IsaTraqEvaluator {
  /// Evaluasi Variabel A: Potensi Kegagalan berdasarkan Persentase Luka & DBH (cm)
  /// Aturan requirements.md:
  /// - if (Persentase Luka < 10%) ➔ Improbable
  /// - if (Persentase Luka >= 10% && Persentase Luka <= 30%) ➔ Possible
  /// - if (Persentase Luka > 30% || DBH < 30 cm) ➔ Probable (Pohon kecil dengan luka sedang = Sangat mungkin patah)
  /// - if (Persentase Luka > 50%) ➔ Imminent (Pasti akan patah/tumbang)
  static FailurePotential evaluateFailurePotential(
    double persentaseLuka,
    double dbhCm,
  ) {
    if (persentaseLuka > 50.0) {
      return FailurePotential.imminent;
    } else if (persentaseLuka > 30.0 || dbhCm < 30.0) {
      return FailurePotential.probable;
    } else if (persentaseLuka >= 10.0 && persentaseLuka <= 30.0) {
      return FailurePotential.possible;
    } else {
      return FailurePotential.improbable;
    }
  }

  /// Evaluasi Matriks ISA TRAQ (Gabungan Variabel A & Variabel B)
  /// Vonis Laporan requirements.md:
  /// - Improbable + Low    ➔ Hijau:  RISIKO RENDAH (Aman)
  /// - Possible + Medium   ➔ Kuning: RISIKO SEDANG (Perlu Dipantau)
  /// - Probable + High     ➔ Oranye: RISIKO TINGGI (Tindak Lanjuti)
  /// - Imminent + High     ➔ Merah:  RISIKO EKSTREM (Tebang Segera!)
  static IsaRiskDecision evaluateMatrix({
    required FailurePotential failurePotential,
    required EnvironmentalImpact environmentalImpact,
  }) {
    // Matriks Standar ISA TRAQ
    switch (failurePotential) {
      case FailurePotential.improbable:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
          case EnvironmentalImpact.medium:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.rendah,
              riskStatus: 'Rendah',
              actionTitle: 'Aman',
              displayText: 'RISIKO RENDAH (Aman)',
              statusColor: AppColors.riskLowText,
            );
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.sedang,
              riskStatus: 'Sedang',
              actionTitle: 'Perlu Dipantau',
              displayText: 'RISIKO SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
        }

      case FailurePotential.possible:
        switch (environmentalImpact) {
          case EnvironmentalImpact.low:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.rendah,
              riskStatus: 'Rendah',
              actionTitle: 'Aman',
              displayText: 'RISIKO RENDAH (Aman)',
              statusColor: AppColors.riskLowText,
            );
          case EnvironmentalImpact.medium:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.sedang,
              riskStatus: 'Sedang',
              actionTitle: 'Perlu Dipantau',
              displayText: 'RISIKO SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.tinggi,
              riskStatus: 'Tinggi',
              actionTitle: 'Tindak Lanjuti',
              displayText: 'RISIKO TINGGI (Tindak Lanjuti)',
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
              displayText: 'RISIKO SEDANG (Perlu Dipantau)',
              statusColor: AppColors.riskMediumText,
            );
          case EnvironmentalImpact.medium:
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.tinggi,
              riskStatus: 'Tinggi',
              actionTitle: 'Tindak Lanjuti',
              displayText: 'RISIKO TINGGI (Tindak Lanjuti)',
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
              displayText: 'RISIKO TINGGI (Tindak Lanjuti)',
              statusColor: AppColors.riskHighText,
            );
          case EnvironmentalImpact.medium:
          case EnvironmentalImpact.high:
            return const IsaRiskDecision(
              riskLevel: RiskLevel.kritis,
              riskStatus: 'Kritis',
              actionTitle: 'Tebang Segera!',
              displayText: 'RISIKO EKSTREM (Tebang Segera!)',
              statusColor: AppColors.riskCriticalText,
            );
        }
    }
  }
}

/// Hasil inferensi YOLO11 Segmentation
class YoloSegmentationResult {
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
        throw StateError('Model segmentasi tidak memiliki input/output yang sesuai.');
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
    initModelBytes(raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes));
  }

  /// Mengubah gambar ke input tensor Float32List NCHW [1, 3, 640, 640] ter-normalisasi [0, 1]
  Float32List imageToFloat32List(img.Image image, {int targetSize = 640}) {
    final resizedImage = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
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

  /// Eksekusi inferensi YOLO11-seg dan kalkulasi area piksel (Tahap 1, 2, 3)
  YoloSegmentationResult? runInference(
    img.Image image, {
    EnvironmentalImpact defaultImpact = EnvironmentalImpact.medium,
  }) {
    if (_session == null) {
      throw StateError('OnnxService belum diinisialisasi');
    }

    const int inputSize = 640;
    final inputData = imageToFloat32List(image, targetSize: inputSize);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3, inputSize, inputSize],
    );

    final runOptions = OrtRunOptions();
    final inputs = {_inputName: inputTensor};

    List<OrtValue?>? outputs;
    try {
      outputs = _session!.run(runOptions, inputs);
      if (outputs.isEmpty) return null;

      final out0Raw = outputs[0]?.value;
      dynamic out1Raw;
      if (outputs.length > 1) {
        out1Raw = outputs[1]?.value;
      }

      return processSegmentationOutputs(
        out0Raw: out0Raw,
        out1Raw: out1Raw,
        defaultImpact: defaultImpact,
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
  }) {
    if (out0Raw is! List || out0Raw.isEmpty) return null;

    // out0 shape: [1, 39, 8400]
    final dynamic data2d = (out0Raw.length == 1 && out0Raw[0] is List)
        ? out0Raw[0]
        : out0Raw;

    // Require the complete segmentation output, not classification scores alone.
    if (data2d is! List || data2d.length != 39) return null;
    if (data2d.any((row) => row is! List)) return null;
    final anchorCount = (data2d[0] as List).length;
    if (anchorCount == 0 ||
        data2d.any((row) => (row as List).length != anchorCount)) {
      return null;
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
    double maxBoxW = 0.0;
    double bestBoxScore = 0.0;

    final int numAnchors = rowC0.length;

    // Ekstraksi deteksi dengan confidence threshold
    // Conservative provisional thresholds. These require field calibration;
    // confidence is not a guarantee that an unfamiliar object is a tree.
    const double confThreshold = 0.70;
    final List<_DetectionBox> detections = [];

    for (int i = 0; i < numAnchors; i++) {
      final sRough = (rowC0[i] as num).toDouble();
      final sHealthy = (rowC1[i] as num).toDouble();
      final sCanker = (rowC2[i] as num).toDouble();
      final w = (rowW[i] as num).toDouble();

      if (![sRough, sHealthy, sCanker].every(
        (score) => score.isFinite && score >= 0 && score <= 1,
      )) {
        return null;
      }

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

      if (maxScore >= confThreshold) {
        final cx = (rowCx[i] as num).toDouble();
        final cy = (rowCy[i] as num).toDouble();
        final h = (rowH[i] as num).toDouble();
        if (![cx, cy, w, h].every((value) => value.isFinite) ||
            w <= 0 || h <= 0) {
          continue;
        }
        final visibleW = (cx + w / 2).clamp(0.0, 640.0) -
            (cx - w / 2).clamp(0.0, 640.0);
        final visibleH = (cy + h / 2).clamp(0.0, 640.0) -
            (cy - h / 2).clamp(0.0, 640.0);
        if (visibleW * visibleH < 640 * 640 * 0.04) continue;

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

    // Validasi apakah objek merupakan pohon
    if (detections.isEmpty) {
      return null; // Objek bukan pohon / tidak terdeteksi
    }

    // -------------------------------------------------------------
    // Tahap 1: Ekstraksi Data (AI ke Angka) via Pixel Area Calculation
    // Rumus: Persentase Luka = (Total Area Piksel Cacat / Total Area Piksel Batang) * 100
    // -------------------------------------------------------------
    int defectPixels = 0;
    int healthyPixels = 0;

    // Jika out1 (prototype masks 32x160x160) tersedia
    final dynamic proto3d = (out1Raw is List && out1Raw.isNotEmpty && out1Raw[0] is List)
        ? out1Raw[0]
        : null;
    if (proto3d is! List || proto3d.length != 32 ||
        proto3d.any((plane) => plane is! List || plane.length != 160 ||
            plane.any((row) => row is! List || row.length != 160))) {
      return null;
    }

    {
      // Grid 160x160 (0: none, 1: healthy, 2: cacat)
      final Uint8List maskGrid = Uint8List(160 * 160);

      // Suppress repeated anchors for the same object before merging masks.
      final retained = <_DetectionBox>[];
      detections.sort((a, b) => b.score.compareTo(a.score));
      for (final det in detections) {
        if (!retained.any((other) => other.classId == det.classId &&
            other.intersectionOverUnion(det) > 0.5)) {
          retained.add(det);
        }
      }
      for (final det in retained) {
        if (det.maskCoeffs == null) continue;
        final coeffs = det.maskCoeffs!;
        final isDefect = (det.classId == 0 || det.classId == 2);
        final labelVal = isDefect ? 2 : 1;

        // Bounding box di grid 160x160 (downsample scale 4x dari 640x640)
        final int x1 = ((det.cx - det.w / 2) / 4).clamp(0, 159).toInt();
        final int y1 = ((det.cy - det.h / 2) / 4).clamp(0, 159).toInt();
        final int x2 = ((det.cx + det.w / 2) / 4).clamp(0, 159).toInt();
        final int y2 = ((det.cy + det.h / 2) / 4).clamp(0, 159).toInt();
        final pixels = <int>[];

        for (int y = y1; y <= y2; y++) {
          final int rowOffset = y * 160;
          for (int x = x1; x <= x2; x++) {
            double logit = 0.0;
            for (int k = 0; k < 32; k++) {
              final rowK = (proto3d[k] as List)[y] as List;
              logit += coeffs[k] * ((rowK[x] as num).toDouble());
            }
            if (!logit.isFinite) return null;

            // Sigmoid activation
            final double prob = 1.0 / (1.0 + exp(-logit));
            if (prob > 0.5) {
              pixels.add(rowOffset + x);
            }
          }
        }
        // A strong box without a substantial segmentation is insufficient.
        final boxPixels = (x2 - x1 + 1) * (y2 - y1 + 1);
        if (pixels.length < 160 * 160 * 0.03 ||
            pixels.length / boxPixels < 0.20) {
          continue;
        }
        for (final idx in pixels) {
          if (maskGrid[idx] < labelVal) maskGrid[idx] = labelVal;
        }
        if (det.classId == 0) maxRough = max(maxRough, det.score);
        if (det.classId == 1) maxHealthy = max(maxHealthy, det.score);
        if (det.classId == 2) maxCanker = max(maxCanker, det.score);
        if (det.score > bestBoxScore) {
          bestBoxScore = det.score;
          maxBoxW = det.w;
        }
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
    if (totalTrunkPixels < 160 * 160 * 0.03) return null;
    double persentaseLuka = (defectPixels / totalTrunkPixels) * 100.0;

    persentaseLuka = double.parse(persentaseLuka.clamp(0.0, 100.0).toStringAsFixed(1));

    // Estimasi DBH (Diameter Batang dalam cm)
    final double estimatedDbh = maxBoxW > 0
        ? double.parse((maxBoxW * 0.18).clamp(20.0, 120.0).toStringAsFixed(1))
        : 65.0;

    // Diagnosa Patologi
    final bool isJamurPelapuk = maxCanker > 0.20 || maxRough > 0.40;
    String detectedCondition;
    if (maxCanker > 0.20) {
      detectedCondition = 'Indikasi Jamur Pelapuk / Canker';
    } else if (maxRough > 0.35) {
      detectedCondition = 'Kulit Batang Kasar & Terkelupas';
    } else {
      detectedCondition = 'Kulit Batang Utuh & Sehat';
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
