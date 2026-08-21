import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/report_tree_card.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Agustus 2026',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 6),
                CircleAvatar(radius: 3, backgroundColor: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const MonthlySummaryCard(),
          const SizedBox(height: 24),
          const ReportTreeCard(
            title: 'Pohon Mahoni',
            address: 'Jl. Kertajaya, Surabaya',
            date: '14 Agt 2026',
            score: 85,
            risk: RiskLevel.rendah,
          ),
          const ReportTreeCard(
            title: 'Pohon Trembesi',
            address: 'Jl. Raya Darmo, Surabaya',
            date: '13 Agt 2026',
            score: 32,
            risk: RiskLevel.kritis,
          ),
          const ReportTreeCard(
            title: 'Pohon Angsana',
            address: 'Jl. Diponegoro, Surabaya',
            date: '12 Agt 2026',
            score: 54,
            risk: RiskLevel.tinggi,
            isOffline: true,
          ),
          const ReportTreeCard(
            title: 'Pohon Tabebuya',
            address: 'Jl. Pemuda, Surabaya',
            date: '10 Agt 2026',
            score: 68,
            risk: RiskLevel.sedang,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}