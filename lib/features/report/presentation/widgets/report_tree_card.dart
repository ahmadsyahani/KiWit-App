import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';

class ReportTreeCard extends StatelessWidget {
  const ReportTreeCard({
    required this.record,
    required this.onTap,
    super.key,
  });

  final SavedInspection record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = record.data;
    final color = switch (record.riskLevel) {
      RiskLevel.rendah => AppColors.primary,
      RiskLevel.sedang => const Color(0xFFA66A08),
      RiskLevel.tinggi => const Color(0xFFCC5E16),
      RiskLevel.kritis => const Color(0xFFB53645),
    };
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE1E8E2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(
                    data.treeSpecies,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w700,
                      fontSize: 16, height: 1.4,
                    ),
                  )),
                  const SizedBox(width: 10),
                  const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFF6C7B70)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  RiskBadge(level: record.riskLevel),
                  Text(formatInspectionDate(data.scanTimestamp), style: const TextStyle(
                    color: Color(0xFF5C7064), fontSize: 11,
                  )),
                  if (!record.isSynced)
                    const Text('Belum sinkron', style: TextStyle(
                      color: Color(0xFF9A571E), fontSize: 11, fontWeight: FontWeight.w600,
                    )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF5C7064)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    data.locationAddress.isEmpty ? 'Alamat belum dicatat' : data.locationAddress,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF5C7064), fontSize: 12, height: 1.5,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Skor kesehatan', style: TextStyle(
                    fontSize: 11, color: Color(0xFF5C7064),
                  ))),
                  Text('${data.healthScore}/100', style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700,
                  )),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: data.healthScore.clamp(0, 100) / 100,
                  minHeight: 5,
                  backgroundColor: const Color(0xFFEEF2EE),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  semanticsLabel: 'Skor kesehatan dari 100',
                  semanticsValue: '${data.healthScore.clamp(0, 100)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
