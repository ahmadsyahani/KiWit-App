import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/presentation/screens/saved_inspection_detail_screen.dart';
import '../../../scan/presentation/widgets/inspection_photo.dart';

class RecentInspectionList extends StatelessWidget {
  const RecentInspectionList({required this.records, super.key});
  final List<SavedInspection> records;

  @override
  Widget build(BuildContext context) {
    final latest = records.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(
            'Inspeksi Terbaru',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (latest.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Belum ada inspeksi tersimpan', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text(
                  'Hasil scan akan muncul di sini setelah disimpan.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        for (final record in latest) ...[
          _inspectionCard(context, record),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _inspectionCard(BuildContext context, SavedInspection record) {
    final data = record.data;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SavedInspectionDetailScreen(record: record)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InspectionPhoto(record: record, width: 70, height: 70),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.treeSpecies,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    RiskBadge(level: record.riskLevel),
                    const SizedBox(height: 6),
                    Text(
                      data.locationAddress.isEmpty ? 'Lokasi belum dicatat' : data.locationAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Skor ${data.healthScore}/100',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          formatInspectionDate(data.scanTimestamp),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    if (!record.isSynced) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Menunggu sinkronisasi',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
