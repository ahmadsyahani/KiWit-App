import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiwit_app/core/providers/supabase_providers.dart';
import 'package:kiwit_app/core/services/onnx_service.dart';
import 'package:kiwit_app/core/widgets/risk_badge.dart';
import 'package:kiwit_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kiwit_app/features/scan/data/repositories/inspection_controller.dart';
import 'package:kiwit_app/features/scan/domain/models/inspection_result_data.dart';
import 'package:kiwit_app/features/scan/presentation/providers/inspection_providers.dart';
import 'package:kiwit_app/features/scan/presentation/screens/inspection_result_screen.dart';

import 'inspection_sync_test.dart' show MemoryLocal, owner, recordAt;
import 'inspection_detail_test.dart' show showDetail;

void main() {
  test(
    'officer provenance survives JSON, while legacy records remain readable',
    () {
      final officer = recordAt('officer', DateTime(2026)).data.copyWith(
        riskStatus: 'Kritis',
        riskAction: 'Prioritaskan pemeriksaan lapangan',
        isOfficerAssessed: true,
        modelRiskStatus: 'Rendah',
      );
      final restored = InspectionResultData.fromJson(
        jsonDecode(jsonEncode(officer.toJson())) as Map<String, dynamic>,
      );
      expect(restored.isOfficerAssessed, isTrue);
      expect(restored.modelRiskStatus, 'Rendah');
      expect(restored.riskStatus, 'Kritis');
      final legacy = officer.toJson()
        ..remove('isOfficerAssessed')
        ..remove('modelRiskStatus');
      expect(InspectionResultData.fromJson(legacy).isOfficerAssessed, isFalse);
      for (final risk in ['Rendah', 'Sedang', 'Tinggi', 'Kritis']) {
        expect(IsaTraqEvaluator.decisionForOfficerRisk(risk).riskStatus, risk);
      }
    },
  );

  testWidgets(
    'manual risk keeps its matching action across environmental edits, save, and detail',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final local = MemoryLocal();
      final source = InspectionController(ownerId: owner, local: local);
      await source.refresh();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            userProfileProvider.overrideWith((ref) async => null),
            inspectionControllerProvider.overrideWith((ref) => source),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => InspectionResultScreen(
                        data: recordAt(
                          'risk',
                          DateTime(2026),
                        ).data.copyWith(persentaseLuka: 0, healthScore: 100),
                      ),
                    ),
                  ),
                  child: const Text('Buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RiskBadge));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kritis'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RiskBadge>(find.byType(RiskBadge)).level,
        RiskLevel.kritis,
      );
      expect(find.text('Penilaian petugas'), findsOneWidget);
      expect(
        find.text('PRIORITAS KRITIS (Periksa di lapangan)'),
        findsOneWidget,
      );
      expect(find.textContaining('Skrining foto: Rendah.'), findsOneWidget);
      await tester.ensureVisible(find.text('High'));
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Skrining foto: Sedang.'), findsOneWidget);
      expect(
        find.text('PRIORITAS KRITIS (Periksa di lapangan)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Simpan Hasil'));
      await tester.pumpAndSettle();
      final saved = local.records.single;
      expect(saved.data.isOfficerAssessed, isTrue);
      expect(saved.data.riskStatus, 'Kritis');
      expect(saved.data.modelRiskStatus, 'Sedang');
      expect(saved.data.riskAction, 'Prioritaskan pemeriksaan lapangan');
      await tester.pumpWidget(const SizedBox());
      await showDetail(tester, saved);
      expect(find.text('Penilaian petugas'), findsOneWidget);
      expect(find.text('Hasil model: Sedang'), findsOneWidget);
      expect(find.text('Prioritaskan pemeriksaan lapangan'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('officer can explicitly return to model risk', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: InspectionResultScreen(
            data: recordAt('risk', DateTime(2026)).data.copyWith(
              riskStatus: 'Kritis',
              riskAction: 'Prioritaskan pemeriksaan lapangan',
              isOfficerAssessed: true,
              modelRiskStatus: 'Rendah',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RiskBadge));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gunakan hasil model'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RiskBadge>(find.byType(RiskBadge)).level,
      RiskLevel.rendah,
    );
    expect(find.text('Penilaian petugas'), findsNothing);
    expect(find.text('PRIORITAS RENDAH (Pantau kondisi)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(800, 600), const Size(320, 640)]) {
    testWidgets('risk picker scrolls at $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: InspectionResultScreen(
              data: recordAt('risk', DateTime(2026)).data,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RiskBadge));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kritis'));
      await tester.tap(find.text('Kritis'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<RiskBadge>(find.byType(RiskBadge)).level,
        RiskLevel.kritis,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
