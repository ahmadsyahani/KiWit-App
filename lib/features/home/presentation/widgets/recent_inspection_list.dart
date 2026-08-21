import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';

class RecentInspectionList extends StatelessWidget {
  const RecentInspectionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(
            'Inspeksi Terbaru',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        _buildInspectionCard(
          title: 'Pohon Mahoni',
          address: 'Jl. Kertajaya, Surabaya',
          date: '14 Agt 2026',
          score: 85,
          risk: RiskLevel.rendah,
        ),
        const SizedBox(height: 12),
        _buildInspectionCard(
          title: 'Pohon Trembesi',
          address: 'Jl. Raya Darmo, Surabaya',
          date: '13 Agt 2026',
          score: 32,
          risk: RiskLevel.kritis,
        ),
      ],
    );
  }

  Widget _buildInspectionCard({
    required String title,
    required String address,
    required String date,
    required int score,
    required RiskLevel risk,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 70,
              height: 70,
              color: AppColors.border, // Placeholder for image
              child: const Icon(Icons.park, color: AppColors.textMuted), // Temp icon instead of image
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RiskBadge(level: risk),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Skor $score/100',
                      style: TextStyle(
                        color: risk == RiskLevel.rendah ? AppColors.primary : AppColors.riskCriticalText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('·', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    ),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
