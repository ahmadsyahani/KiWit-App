import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';

class ReportTreeCard extends StatelessWidget {
  final String title;
  final String address;
  final String date;
  final int score;
  final RiskLevel risk;
  final bool isOffline;

  const ReportTreeCard({
    super.key,
    required this.title,
    required this.address,
    required this.date,
    required this.score,
    required this.risk,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    Color getRiskColor() {
      switch (risk) {
        case RiskLevel.rendah:
          return AppColors.primary;
        case RiskLevel.kritis:
          return AppColors.riskCriticalText;
        case RiskLevel.tinggi:
          return Colors.orange;
        case RiskLevel.sedang:
          return Colors.amber;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RiskBadge(level: risk),
                ],
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                address,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              if (isOffline)
                const Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(getRiskColor()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$score/100',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}