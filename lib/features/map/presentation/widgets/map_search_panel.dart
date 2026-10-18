import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';

class MapSearchPanel extends StatelessWidget {
  const MapSearchPanel({
    required this.controller,
    required this.hasFilter,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilter,
    super.key,
  });

  final TextEditingController controller;
  final bool hasFilter;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: const Color(0x18094228),
    borderRadius: BorderRadius.circular(18),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
            decoration: InputDecoration(
              hintText: 'Cari pohon, kode, atau jalan',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF5C7064)),
              prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.primary),
              suffixIcon: controller.text.isEmpty ? null : IconButton(
                tooltip: 'Hapus pencarian',
                onPressed: onClear,
                icon: const Icon(LucideIcons.x, size: 17),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        Container(width: 1, height: 24, color: const Color(0xFFE1E9E2)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: IconButton(
            tooltip: 'Filter risiko dan rayon',
            onPressed: onFilter,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: hasFilter ? Colors.white : AppColors.primary,
              backgroundColor: hasFilter ? AppColors.primary : Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
          ),
        ),
      ],
    ),
  );
}

String mapRiskLabel(RiskLevel? risk) => switch (risk) {
  null => 'Semua',
  RiskLevel.rendah => 'Rendah',
  RiskLevel.sedang => 'Sedang',
  RiskLevel.tinggi => 'Tinggi',
  RiskLevel.kritis => 'Kritis',
};
