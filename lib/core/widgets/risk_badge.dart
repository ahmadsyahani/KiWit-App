import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum RiskLevel { rendah, sedang, tinggi, kritis }

class RiskBadge extends StatelessWidget {
  final RiskLevel level;

  const RiskBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label;

    switch (level) {
      case RiskLevel.rendah:
        bg = AppColors.riskLowBg;
        text = AppColors.riskLowText;
        label = 'Rendah';
        break;
      case RiskLevel.sedang:
        bg = AppColors.riskMediumBg;
        text = AppColors.riskMediumText;
        label = 'Sedang';
        break;
      case RiskLevel.tinggi:
        bg = AppColors.riskHighBg;
        text = AppColors.riskHighText;
        label = 'Tinggi';
        break;
      case RiskLevel.kritis:
        bg = AppColors.riskCriticalBg;
        text = AppColors.riskCriticalText;
        label = 'Kritis';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
