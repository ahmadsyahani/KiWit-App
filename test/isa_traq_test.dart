import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/services/onnx_service.dart';
import 'package:kiwit_app/core/widgets/risk_badge.dart';

void main() {
  group('ISA TRAQ Requirements.md Specifications', () {
    test('Variabel A: Potensi Kegagalan evaluation', () {
      // Rule 1: if (Persentase Luka < 10%) -> Improbable (with DBH >= 30)
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(5.0, 35.0),
        FailurePotential.improbable,
      );

      // Rule 2: if (Persentase Luka >= 10% && Persentase Luka <= 30%) -> Possible (with DBH >= 30)
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(15.0, 40.0),
        FailurePotential.possible,
      );
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(30.0, 30.0),
        FailurePotential.possible,
      );

      // Rule 3: if (Persentase Luka > 30% || DBH < 30 cm) -> Probable
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(35.0, 50.0),
        FailurePotential.probable,
      );
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(8.0, 20.0), // Pohon kecil DBH < 30 cm
        FailurePotential.probable,
      );

      // Rule 4: if (Persentase Luka > 50%) -> Imminent
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(55.0, 25.0),
        FailurePotential.imminent,
      );
      expect(
        IsaTraqEvaluator.evaluateFailurePotential(70.0, 60.0),
        FailurePotential.imminent,
      );
    });

    test('Tahap 3: Keputusan Akhir (Vonis Laporan) Anchor Points', () {
      // 1. Improbable + Low -> RISIKO RENDAH (Aman) [Hijau]
      final r1 = IsaTraqEvaluator.evaluateMatrix(
        failurePotential: FailurePotential.improbable,
        environmentalImpact: EnvironmentalImpact.low,
      );
      expect(r1.riskLevel, RiskLevel.rendah);
      expect(r1.displayText, 'RISIKO RENDAH (Aman)');

      // 2. Possible + Medium -> RISIKO SEDANG (Perlu Dipantau) [Kuning]
      final r2 = IsaTraqEvaluator.evaluateMatrix(
        failurePotential: FailurePotential.possible,
        environmentalImpact: EnvironmentalImpact.medium,
      );
      expect(r2.riskLevel, RiskLevel.sedang);
      expect(r2.displayText, 'RISIKO SEDANG (Perlu Dipantau)');

      // 3. Probable + High -> RISIKO TINGGI (Tindak Lanjuti) [Oranye]
      final r3 = IsaTraqEvaluator.evaluateMatrix(
        failurePotential: FailurePotential.probable,
        environmentalImpact: EnvironmentalImpact.high,
      );
      expect(r3.riskLevel, RiskLevel.tinggi);
      expect(r3.displayText, 'RISIKO TINGGI (Tindak Lanjuti)');

      // 4. Imminent + High -> RISIKO EKSTREM (Tebang Segera!) [Merah]
      final r4 = IsaTraqEvaluator.evaluateMatrix(
        failurePotential: FailurePotential.imminent,
        environmentalImpact: EnvironmentalImpact.high,
      );
      expect(r4.riskLevel, RiskLevel.kritis);
      expect(r4.displayText, 'RISIKO EKSTREM (Tebang Segera!)');
    });
  });
}
