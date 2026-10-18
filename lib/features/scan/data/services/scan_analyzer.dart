import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../../../core/services/onnx_service.dart';

abstract interface class ScanAnalyzer {
  Future<void> prepare();
  Future<YoloSegmentationResult?> analyze(String imagePath);
}

/// Decoding, orientation correction, inference and mask processing run off the UI.
class OnnxPhotoAnalyzer implements ScanAnalyzer {
  Uint8List? _bytes;
  Future<void>? _preparing;

  @override
  Future<void> prepare() => _preparing ??= _load();

  Future<void> _load() async {
    try {
      final data = await rootBundle.load('assets/models/best.onnx');
      _bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      _preparing = null;
      rethrow;
    }
  }

  @override
  Future<YoloSegmentationResult?> analyze(String imagePath) async {
    await prepare();
    final values = await compute(_analyzePhoto, (imagePath, _bytes!));
    if (values == null) return null;
    final failure = FailurePotential.fromString(values['failure'] as String);
    return YoloSegmentationResult(
      isValidTree: true,
      healthyPixels: values['healthy'] as int,
      defectPixels: values['defect'] as int,
      totalTrunkPixels: values['total'] as int,
      persentaseLuka: values['damage'] as double,
      maxConfidenceRough: values['rough'] as double,
      maxConfidenceHealthy: values['healthyConfidence'] as double,
      maxConfidenceCanker: values['canker'] as double,
      isJamurPelapuk: values['fungus'] as bool,
      detectedCondition: values['condition'] as String,
      estimatedDbhCm: values['dbh'] as double,
      failurePotential: failure,
      riskDecision: IsaTraqEvaluator.evaluateMatrix(
        failurePotential: failure,
        environmentalImpact: EnvironmentalImpact.medium,
      ),
    );
  }
}

Map<String, Object>? _analyzePhoto((String, Uint8List) input) {
  final decoded = img.decodeImage(File(input.$1).readAsBytesSync());
  if (decoded == null) throw const FormatException('Foto tidak dapat dibaca.');
  final service = OnnxService();
  try {
    service.initModelBytes(input.$2);
    final result = service.runInference(img.bakeOrientation(decoded));
    if (result == null || !result.isValidTree) return null;
    return {
      'healthy': result.healthyPixels,
      'defect': result.defectPixels,
      'total': result.totalTrunkPixels,
      'damage': result.persentaseLuka,
      'rough': result.maxConfidenceRough,
      'healthyConfidence': result.maxConfidenceHealthy,
      'canker': result.maxConfidenceCanker,
      'fungus': result.isJamurPelapuk,
      'condition': result.detectedCondition,
      'dbh': result.estimatedDbhCm,
      'failure': result.failurePotential.label,
    };
  } finally {
    service.dispose();
  }
}
