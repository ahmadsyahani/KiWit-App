import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/presentation/widgets/inspection_photo.dart';
import '../../data/models/tree_map_model.dart';

class MapInspectionCard extends StatelessWidget {
  const MapInspectionCard({
    required this.marker,
    required this.onDetail,
    required this.onClose,
    this.onPrevious,
    this.onNext,
    this.position,
    this.total,
    super.key,
  });

  final TreeMapModel marker;
  final VoidCallback onDetail;
  final VoidCallback onClose;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final int? position;
  final int? total;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 3,
    shadowColor: const Color(0x22094228),
    borderRadius: BorderRadius.circular(24),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text('Inspeksi #${marker.treeCode}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12, color: Color(0xFF5C7064), fontWeight: FontWeight.w600,
                ),
              )),
              IconButton(
                onPressed: onClose,
                tooltip: 'Tutup detail pin',
                icon: const Icon(LucideIcons.x, size: 18),
              ),
            ],
          ),
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: InspectionPhoto(record: marker.record, width: 60, height: 76),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(marker.speciesName,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, height: 1.3, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  RiskBadge(level: marker.riskLevel),
                ],
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.mapPin, size: 15, color: Color(0xFF5C7064)),
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(
                marker.address.isEmpty ? 'Alamat belum dicatat' : marker.address,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF5C7064)),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12, runSpacing: 5,
            children: [
              Text(formatInspectionDate(marker.record.data.scanTimestamp),
                style: const TextStyle(fontSize: 11, color: Color(0xFF5C7064))),
              Text(marker.isSynced ? 'Tersinkron' : 'Tersimpan di perangkat',
                style: const TextStyle(fontSize: 11, color: AppColors.primary)),
            ],
          ),
          if (onPrevious != null || onNext != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Inspeksi sebelumnya',
                  onPressed: onPrevious,
                  icon: const Icon(LucideIcons.chevronLeft, size: 20),
                ),
                Expanded(child: Text(position != null && total != null
                    ? '$position dari $total inspeksi' : 'Jelajahi inspeksi',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5C7064)),
                )),
                IconButton(
                  tooltip: 'Inspeksi berikutnya',
                  onPressed: onNext,
                  icon: const Icon(LucideIcons.chevronRight, size: 20),
                ),
              ],
            ),
          ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onDetail,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Lihat detail inspeksi', textAlign: TextAlign.center),
          ),
        ],
      ),
    ),
  );
}
