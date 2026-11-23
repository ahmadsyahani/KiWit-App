import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../data/models/saved_inspection.dart';
import '../../domain/models/inspection_location.dart';
import '../../domain/models/inspection_result_data.dart';
import '../providers/inspection_providers.dart';
import '../widgets/inspection_photo.dart';

class SavedInspectionDetailScreen extends ConsumerWidget {
  const SavedInspectionDetailScreen({required this.record, super.key});
  final SavedInspection record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var current = record;
    final records = ref
        .watch(inspectionControllerProvider)
        .valueOrNull
        ?.records;
    for (final candidate in records ?? <SavedInspection>[]) {
      if (candidate.id == record.id && candidate.ownerId == record.ownerId) {
        current = candidate;
        break;
      }
    }
    final data = current.data;
    final (riskColor, riskBackground) = switch (current.riskLevel) {
      RiskLevel.belumDinilai => (
        const Color(0xFF596570),
        const Color(0xFFEDF0F2),
      ),
      RiskLevel.rendah => (AppColors.riskLowText, AppColors.riskLowBg),
      RiskLevel.sedang => (AppColors.riskMediumText, AppColors.riskMediumBg),
      RiskLevel.tinggi => (AppColors.riskHighText, AppColors.riskHighBg),
      RiskLevel.kritis => (
        AppColors.riskCriticalText,
        AppColors.riskCriticalBg,
      ),
    };
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Detail inspeksi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(14) > 19;
                    final height = largeText
                        ? 310.0
                        : (constraints.maxWidth / 1.65).clamp(210.0, 290.0);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: SizedBox(
                        height: height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InspectionPhoto(
                              record: current,
                              width: double.infinity,
                              height: height,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0xD9112D21),
                                  ],
                                  stops: [.25, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 18,
                              bottom: 18,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RiskBadge(level: current.riskLevel),
                                  const SizedBox(height: 8),
                                  Text(
                                    _value(
                                      data.treeSpecies,
                                      'Jenis pohon belum ditentukan',
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      height: 1.25,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _dateTime(data.scanTimestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                      color: Color(0xFFE0ECE4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _summary(data),
                const SizedBox(height: 24),
                _heading('Arahan tindak lanjut', Icons.fact_check_outlined),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: riskBackground.withValues(alpha: .32),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: riskColor.withValues(alpha: .16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _value(data.followUpAction, 'Belum dicatat'),
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: riskColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.isOfficerAssessed
                            ? 'Penilaian petugas'
                            : data.hasAssessment
                            ? 'Skrining foto'
                            : 'Belum ada penilaian',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (data.isOfficerAssessed &&
                          data.modelRiskStatus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Hasil model: ${data.modelRiskStatus}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Cocokkan hasil analisis dengan pemeriksaan di lapangan.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _heading('Hasil pemeriksaan', Icons.monitor_heart_outlined),
                if (data.hasAssessment)
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _resultRow(
                          Icons.texture_rounded,
                          'Kondisi terdeteksi',
                          _value(data.detectedCondition, 'Belum dicatat'),
                        ),
                        const Divider(height: 28, color: AppColors.divider),
                        _resultRow(
                          Icons.analytics_outlined,
                          'Area pola kerusakan pada foto',
                          '${data.persentaseLuka.toStringAsFixed(1)}%',
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (data.persentaseLuka / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            color: riskColor,
                            backgroundColor: AppColors.divider,
                          ),
                        ),
                        const Divider(height: 28, color: AppColors.divider),
                        _resultRow(
                          Icons.eco_outlined,
                          'Jamur pelapuk',
                          data.hasPathologyAssessment
                              ? (data.isJamurPelapuk
                                    ? 'Tercatat positif'
                                    : 'Tercatat negatif')
                              : 'Tidak dinilai',
                        ),
                        const Divider(height: 28, color: AppColors.divider),
                        const Text(
                          'Indeks tampilan kulit pada foto',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${data.healthScore} / 100',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Hasil foto adalah skrining awal. Diameter, kemiringan, dan penyebab kerusakan memerlukan pemeriksaan langsung.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _panel(
                    const Text(
                      'Kondisi belum dapat dinilai. Foto tersimpan untuk pemeriksaan manual; skor kesehatan, kondisi, dan risiko belum ditentukan.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _heading('Riwayat laporan', Icons.history_rounded),
                _panel(
                  Column(
                    children: [
                      _timeline(
                        'Foto diambil',
                        _dateTime(data.scanTimestamp),
                        Icons.camera_alt_outlined,
                        last: false,
                      ),
                      _timeline(
                        'Hasil disimpan',
                        _dateTime(current.savedAt),
                        Icons.assignment_turned_in_outlined,
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _heading('Lokasi pohon', Icons.location_on_outlined),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _value(data.locationAddress, 'Lokasi belum dicatat'),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Koordinat',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        validInspectionCoordinates(
                              data.latitude,
                              data.longitude,
                            )
                            ? '${data.latitude!.toStringAsFixed(6)}, ${data.longitude!.toStringAsFixed(6)}'
                            : 'Belum tersedia',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _heading('Informasi inspeksi', Icons.assignment_outlined),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _info(
                        'Petugas',
                        _value(current.inspectorName, 'Belum dicatat'),
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      _info('Rayon', _value(current.rayon, 'Belum dicatat')),
                      const Divider(height: 24, color: AppColors.divider),
                      _info(
                        'ID inspeksi',
                        _value(data.inspectionId, 'Belum tersedia'),
                      ),
                      const Divider(height: 24, color: AppColors.divider),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            current.isSynced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  current.isSynced
                                      ? 'Tersinkron ke cloud'
                                      : 'Tersimpan di perangkat',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (!current.isSynced) ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Menunggu sinkronisasi',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _heading('Catatan petugas', Icons.notes_rounded),
                _panel(
                  SelectableText(
                    _value(current.notes, 'Belum ada catatan tambahan.'),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _value(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();
  String _dateTime(DateTime value) {
    final local = value.toLocal();
    return '${formatInspectionDate(local)} - ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _summary(InspectionResultData data) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 280 ||
              MediaQuery.textScalerOf(context).scale(12) > 16
          ? 1
          : 3;
      final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _stat(
            width,
            'Spesies',
            _value(
              data.treeSpecies.replaceFirst(RegExp(r'^Pohon\s+'), ''),
              'Belum ditentukan',
            ),
          ),
          _stat(
            width,
            'DBH',
            data.hasAssessment && data.hasMeasuredDiameter
                ? '${data.diameter.toStringAsFixed(1)} cm'
                : 'Belum diukur',
          ),
          _stat(
            width,
            'Kemiringan',
            data.hasAssessment && data.hasMeasuredInclination
                ? '${data.sudutKemiringan.toStringAsFixed(1)}\u00B0'
                : 'Belum diukur',
          ),
        ],
      );
    },
  );

  Widget _stat(double width, String label, String value) => Container(
    width: width,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F8F5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            height: 1.5,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _heading(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEBF0ED)),
    ),
    child: child,
  );

  Widget _resultRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F8F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _timeline(
    String title,
    String date,
    IconData icon, {
    required bool last,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 30,
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F7F2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: AppColors.primary),
            ),
            if (!last)
              Container(width: 1, height: 30, color: const Color(0xFFDCE7DF)),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: last ? 0 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _info(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 5),
      SelectableText(
        value,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    ],
  );
}
