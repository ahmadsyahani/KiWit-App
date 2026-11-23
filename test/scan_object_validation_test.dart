import 'dart:ui' show Rect;
import 'package:image/image.dart' as img;
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

List<List<List<List<double>>>> masks({double logit = 1, bool sparse = false}) =>
    [
      List.generate(
        32,
        (k) => List.generate(
          160,
          (y) => List.generate(
            160,
            (x) => k == 0 && (!sparse || x == 80) ? logit : -1.0,
          ),
        ),
      ),
    ];

void main() {
  final service = OnnxService();
  YoloSegmentationResult? evaluate(dynamic detections, dynamic prototypes) =>
      service.processSegmentationOutputs(
        out0Raw: detections,
        out1Raw: prototypes,
        defaultImpact: EnvironmentalImpact.medium,
      );

  test(
    'optional audit letterbox preserves proportions with RGB114 padding',
    () {
      for (final size in [(4, 8), (8, 4)]) {
        final image = img.Image(width: size.$1, height: size.$2);
        img.fill(image, color: img.ColorRgb8(255, 0, 0));
        final tensor = service.imageToFloat32List(
          image,
          targetSize: 8,
          preserveAspectRatio: true,
        );
        expect(tensor.length, 3 * 8 * 8);
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final inside = size.$1 == 4 ? x >= 2 && x < 6 : y >= 2 && y < 6;
            final index = y * 8 + x;
            expect(tensor[index], closeTo(inside ? 1 : 114 / 255, .00001));
            expect(tensor[64 + index], closeTo(inside ? 0 : 114 / 255, .00001));
            expect(
              tensor[128 + index],
              closeTo(inside ? 0 : 114 / 255, .00001),
            );
          }
        }
      }
    },
  );

  test('production preprocessing matches training stretch without padding', () {
    for (final dimensions in [(4, 8), (8, 4)]) {
      final image = img.Image(width: dimensions.$1, height: dimensions.$2);
      img.fill(image, color: img.ColorRgb8(255, 0, 0));
      final tensor = service.imageToFloat32List(image, targetSize: 8);
      expect(tensor.sublist(0, 64), everyElement(1.0));
      expect(tensor.sublist(64), everyElement(0.0));
    }
  });

  test('padding cannot count as bark or inflate mask coverage', () {
    const bounds = Rect.fromLTWH(160, 0, 320, 640);
    final result = service.processSegmentationOutputs(
      out0Raw: boxes(width: 640, height: 640),
      out1Raw: masks(),
      defaultImpact: EnvironmentalImpact.medium,
      inputBounds: bounds,
    );
    expect(result!.totalTrunkPixels, 80 * 160);
    expect(
      service.processSegmentationOutputs(
        out0Raw: boxes(cx: 60, width: 100),
        out1Raw: masks(),
        defaultImpact: EnvironmentalImpact.medium,
        inputBounds: bounds,
      ),
      isNull,
    );
  });

  test('area limits use photo content instead of padded square', () {
    final detection = boxes(width: 100, height: 90);
    expect(evaluate(detection, masks()), isNull);
    final result = service.processSegmentationOutputs(
      out0Raw: detection,
      out1Raw: masks(),
      defaultImpact: EnvironmentalImpact.medium,
      inputBounds: const Rect.fromLTWH(160, 0, 320, 640),
    );
    expect(result, isNotNull);
    expect(result!.totalTrunkPixels, lessThan(768));
  });

  test(
    'diagnostics distinguish weak scores, insufficient mask and invalid output',
    () {
      final cases = [
        (boxes(score: .5), masks(), BarkRejectionReason.lowConfidence),
        (boxes(), masks(logit: -1), BarkRejectionReason.insufficientMask),
        (boxes(), null, BarkRejectionReason.invalidOutput),
      ];
      for (final entry in cases) {
        BarkRejectionReason? reason;
        expect(
          service.processSegmentationOutputs(
            out0Raw: entry.$1,
            out1Raw: entry.$2,
            defaultImpact: EnvironmentalImpact.medium,
            onRejected: (value) => reason = value,
          ),
          isNull,
        );
        expect(reason, entry.$3);
      }
    },
  );

  test('old weak 15-69 percent scores cannot create an inspection', () {
    for (final score in [.15, .19, .20, .50, .69]) {
      expect(evaluate(boxes(score: score), masks()), isNull);
    }
  });

  test('invalid outputs expose a stable code for each failing contract', () {
    const fullBounds = Rect.fromLTWH(0, 0, 640, 640);
    final cases = [
      (boxes(), masks(), const Rect.fromLTWH(-1, 0, 640, 640), 'SCAN-01'),
      (
        [
          [
            [1.0],
          ],
        ],
        masks(),
        fullBounds,
        'SCAN-02',
      ),
      (boxes(score: double.nan), masks(), fullBounds, 'SCAN-03'),
      (boxes(), null, fullBounds, 'SCAN-04'),
      (boxes(), masks(logit: double.nan), fullBounds, 'SCAN-05'),
    ];
    for (final entry in cases) {
      String? code;
      BarkRejectionReason? reason;
      final result = service.processSegmentationOutputs(
        out0Raw: entry.$1,
        out1Raw: entry.$2,
        inputBounds: entry.$3,
        defaultImpact: EnvironmentalImpact.medium,
        onRejected: (value) => reason = value,
        onInvalidOutput: (value) => code = value,
      );
      expect(result, isNull);
      expect(reason, BarkRejectionReason.invalidOutput);
      expect(code, entry.$4);
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

  test(
    'rough and canker-like bark proceed without a healthy-class detection',
    () {
      for (final classId in [0, 2]) {
        final result = evaluate(boxes(classId: classId), masks());
        expect(result, isNotNull);
        expect(
          result!.defectPixels,
          classId == 2 ? result.totalTrunkPixels : 0,
        );
        expect(result.persentaseLuka, classId == 2 ? 100 : 0);
      }
    },
  );

  test(
    'observed Android sigmoid roundoff does not discard other detections',
    () {
      final detections = boxes(copies: 2);
      // First anchor matches the values captured from the actual Android log.
      detections[0][4][0] = -5.960464477539063e-8;
      detections[0][5][0] = 3.5762786865234375e-7;
      detections[0][6][0] = 2.9802322387695312e-8;
      final result = evaluate(detections, masks());
      expect(result, isNotNull);
      expect(result!.maxConfidenceHealthy, .9);
      expect(result.persentaseLuka, 0);
    },
  );

  test(
    'roundoff alone stays below confidence threshold without invalid output',
    () {
      final detections = boxes(score: 0);
      detections[0][4][0] = -5.960464477539063e-8;
      BarkRejectionReason? reason;
      String? code;
      expect(
        service.processSegmentationOutputs(
          out0Raw: detections,
          out1Raw: masks(),
          defaultImpact: EnvironmentalImpact.medium,
          onRejected: (value) => reason = value,
          onInvalidOutput: (value) => code = value,
        ),
        isNull,
      );
      expect(reason, BarkRejectionReason.lowConfidence);
      expect(code, isNull);
    },
  );

  test(
    'only tiny finite score overshoots are clamped to probability bounds',
    () {
      expect(
        evaluate(
          boxes(score: 1 + 1.1920928955078125e-7),
          masks(),
        )!.maxConfidenceHealthy,
        1,
      );
      for (final invalid in [-.001, 1.0001, double.infinity, double.nan]) {
        expect(evaluate(boxes(score: invalid), masks()), isNull);
      }
    },
  );

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
    expect(
      evaluate([
        [
          [1.0],
        ],
      ], masks()),
      isNull,
    );
    expect(
      evaluate(boxes(), [
        [
          [
            [1.0],
          ],
        ],
      ]),
      isNull,
    );
    expect(evaluate(boxes(), masks(logit: double.nan)), isNull);
  });
}
