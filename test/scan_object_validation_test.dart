import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/services/onnx_service.dart';

// Synthetic tensors exercise the actual acceptance boundary without loading
// native ONNX. They do not measure tree/non-tree recognition accuracy.
List<List<List<double>>> boxes({
  double score = .9,
  int classId = 1,
  double width = 320,
  double height = 480,
  double cx = 320,
  double cy = 320,
  int copies = 1,
}) {
  final rows = List.generate(39, (_) => List.filled(copies, 0.0));
  for (var i = 0; i < copies; i++) {
    rows[0][i] = cx;
    rows[1][i] = cy;
    rows[2][i] = width;
    rows[3][i] = height;
    rows[4 + classId][i] = score;
    rows[7][i] = 1;
  }
  return [rows];
}

List<List<List<List<double>>>> masks({
  double logit = 1,
  bool sparse = false,
}) => [
  List.generate(32, (k) => List.generate(160, (y) =>
    List.generate(160, (x) => k == 0 && (!sparse || x == 80)
        ? logit : -1.0))),
];

void main() {
  final service = OnnxService();
  YoloSegmentationResult? evaluate(dynamic detections, dynamic prototypes) =>
      service.processSegmentationOutputs(
        out0Raw: detections,
        out1Raw: prototypes,
        defaultImpact: EnvironmentalImpact.medium,
      );

  test('old weak 15-69 percent scores cannot create an inspection', () {
    for (final score in [.15, .19, .20, .50, .69]) {
      expect(evaluate(boxes(score: score), masks()), isNull);
    }
  });

  test('strong healthy bark with substantial mask can proceed', () {
    final result = evaluate(boxes(), masks());
    expect(result, isNotNull);
    expect(result!.isValidTree, isTrue);
    expect(result.totalTrunkPixels, greaterThanOrEqualTo(768));
    expect(result.persentaseLuka, 0);
    expect(result.maxConfidenceHealthy, .9);
  });

  test('damaged bark does not require a healthy class to pass', () {
    for (final classId in [0, 2]) {
      final result = evaluate(boxes(classId: classId), masks());
      expect(result, isNotNull);
      expect(result!.defectPixels, result.totalTrunkPixels);
      expect(result.persentaseLuka, 100);
    }
  });

  test('high scores without masks or with empty masks are rejected', () {
    expect(evaluate(boxes(), null), isNull);
    expect(evaluate(boxes(), masks(logit: -1)), isNull);
    expect(evaluate(boxes(), masks(logit: 0)), isNull);
  });

  test('tiny boxes and sparse masks cannot establish a trunk', () {
    expect(evaluate(boxes(width: 30, height: 30), masks()), isNull);
    expect(evaluate(boxes(), masks(sparse: true)), isNull);
  });

  test('boxes outside the image and nonfinite geometry are rejected', () {
    expect(evaluate(boxes(cx: -1000), masks()), isNull);
    expect(evaluate(boxes(width: double.nan), masks()), isNull);
    expect(evaluate(boxes(height: -480), masks()), isNull);
  });

  test('repeated anchors do not multiply accepted mask area', () {
    final single = evaluate(boxes(), masks())!;
    final repeated = evaluate(boxes(copies: 4), masks())!;
    expect(repeated.totalTrunkPixels, single.totalTrunkPixels);
    expect(repeated.persentaseLuka, single.persentaseLuka);
  });

  test('invalid scores and segmentation outputs cannot create results', () {
    expect(evaluate(boxes(score: double.nan), masks()), isNull);
    expect(evaluate(boxes(score: 1.1), masks()), isNull);
    expect(evaluate([[[1.0]]], masks()), isNull);
    expect(evaluate(boxes(), [[[[1.0]]]]), isNull);
    expect(evaluate(boxes(), masks(logit: double.nan)), isNull);
  });
}
