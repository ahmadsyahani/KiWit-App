import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../scan/data/repositories/inspection_controller.dart';
import '../../data/repositories/tree_map_repository.dart';

class MapDataStatusCard extends StatelessWidget {
  const MapDataStatusCard({
    required this.data,
    required this.feed,
    required this.isGuest,
    required this.onRefresh,
    required this.onStartScan,
    required this.onWithoutLocation,
    this.onClearFilters,
    this.onShowList,
    super.key,
  });

  final AsyncValue<MapInspectionData> data;
  final AsyncValue<InspectionFeed> feed;
  final bool isGuest;
  final VoidCallback onRefresh;
  final VoidCallback onStartScan;
  final VoidCallback onWithoutLocation;
  final VoidCallback? onClearFilters;
  final VoidCallback? onShowList;

  @override
  Widget build(BuildContext context) {
    final result = data.valueOrNull;
    final value = feed.valueOrNull;
    final String title;
    final String subtitle;
    if (data.hasError) {
      title = 'Data inspeksi belum dapat dimuat';
      subtitle = 'Coba muat ulang data yang tersimpan.';
    } else if (result == null) {
      title = 'Memuat inspeksi';
      subtitle = 'Menyiapkan titik pada peta.';
    } else if (!isGuest && value?.syncing == true && result.totalCount == 0) {
      title = 'Memuat inspeksi akun';
      subtitle = 'Memeriksa data yang tersimpan di cloud.';
    } else if (!isGuest && value?.syncIssue != null && result.totalCount == 0) {
      title = 'Data cloud belum dapat dimuat';
      subtitle = 'Belum ada salinan di perangkat ini. Coba muat ulang saat terhubung.';
    } else if (result.totalCount == 0) {
      title = 'Belum ada inspeksi tersimpan';
      subtitle = 'Mulai inspeksi pertama. Lokasi dicari otomatis saat mengambil foto.';
    } else if (result.matchingCount == 0) {
      title = 'Tidak ada hasil yang cocok';
      subtitle = 'Coba kata kunci, rayon, atau tingkat risiko lain.';
    } else if (result.markers.isEmpty) {
      title = 'Lokasi inspeksi belum tersedia';
      subtitle = 'Inspeksi yang cocok belum memiliki koordinat valid.';
    } else {
      title = '${result.markers.length} titik inspeksi';
      subtitle = isGuest
          ? 'Data tamu di perangkat ini.'
          : value?.syncing == true
              ? 'Menyinkronkan inspeksi akun Anda...'
              : value?.syncIssue != null
                  ? 'Sinkronisasi tertunda. Data perangkat tetap ditampilkan.'
                  : value != null && value.pendingCount > 0
                      ? '${value.pendingCount} inspeksi menunggu sinkron.'
                      : 'Data inspeksi akun Anda.';
    }

    final loading = value?.syncing == true || data.isLoading;
    final canStart = result != null &&
        !(result.totalCount == 0 && !isGuest &&
            (value?.syncIssue != null || value?.syncing == true));
    final hasResults = result != null && result.matchingCount > 0;
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x22094228),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
                ))),
                IconButton(
                  tooltip: 'Muat ulang inspeksi',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.primary),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(subtitle, style: const TextStyle(
                fontSize: 12, color: Color(0xFF5C7064), height: 1.5,
              )),
            ),
            if (result != null && result.withoutLocation.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onWithoutLocation,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text('${result.withoutLocation.length} inspeksi belum bisa dipetakan',
                    style: const TextStyle(fontSize: 12)),
                ),
              ),
            if (result != null && result.matchingCount == 0 &&
                result.totalCount > 0 && onClearFilters != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: onClearFilters, child: const Text('Hapus filter')),
              ),
            if (canStart) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (hasResults && onShowList != null) ...[
                    IconButton.outlined(
                      tooltip: 'Daftar inspeksi pada peta',
                      onPressed: onShowList,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: Color(0xFFDCE6DE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(LucideIcons.list, size: 20),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: FilledButton.icon(
                    onPressed: onStartScan,
                    icon: const Icon(LucideIcons.camera, size: 18),
                    label: const Text('Inspeksi baru', textAlign: TextAlign.center),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
