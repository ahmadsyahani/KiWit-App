import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../data/models/saved_inspection.dart';
import '../../domain/models/inspection_location.dart';
import '../providers/inspection_providers.dart';
import '../widgets/inspection_photo.dart';

class SavedInspectionDetailScreen extends ConsumerWidget {
  const SavedInspectionDetailScreen({required this.record, super.key});
  final SavedInspection record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var current = record;
    final records = ref.watch(inspectionControllerProvider).valueOrNull?.records;
    for (final candidate in records ?? <SavedInspection>[]) {
      if (candidate.id == record.id) {
        current = candidate;
        break;
      }
    }
    final data = current.data;
    final timestamp = data.scanTimestamp.toLocal();
    final time = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final (riskColor, riskBackground) = switch (current.riskLevel) {
      RiskLevel.rendah => (AppColors.riskLowText, AppColors.riskLowBg),
      RiskLevel.sedang => (AppColors.riskMediumText, AppColors.riskMediumBg),
      RiskLevel.tinggi => (AppColors.riskHighText, AppColors.riskHighBg),
      RiskLevel.kritis => (AppColors.riskCriticalText, AppColors.riskCriticalBg),
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail inspeksi',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: LayoutBuilder(builder: (context, constraints) =>
                InspectionPhoto(record: current, width: double.infinity,
                  height: (constraints.maxWidth / 1.55).clamp(180.0, 300.0))),
            ),
            const SizedBox(height: 20),
            Text(
              _value(data.treeSpecies, 'Jenis pohon belum ditentukan'),
              style: const TextStyle(fontSize: 25, height: 1.25,
                fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.calendar_today_outlined, size: 15,
                  color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('${formatInspectionDate(timestamp)} · $time',
                style: const TextStyle(fontSize: 13, height: 1.5,
                  color: AppColors.textSecondary))),
            ]),
            const SizedBox(height: 22),

            // Risk and next action stay together, before the technical details.
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: riskBackground.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: riskColor.withValues(alpha: .18)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                  spacing: 10, runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Status risiko', style: TextStyle(
                      color: riskColor, fontSize: 13, fontWeight: FontWeight.w600)),
                    RiskBadge(level: current.riskLevel),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Arahan tindak lanjut',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 5),
                Text(_value(data.riskAction, 'Belum dicatat'),
                  style: TextStyle(fontSize: 20, height: 1.35,
                    fontWeight: FontWeight.w700, color: riskColor)),
                const SizedBox(height: 8),
                const Text('Cocokkan hasil analisis dengan pemeriksaan di lapangan.',
                  style: TextStyle(fontSize: 12, height: 1.5,
                    color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 28),

            _heading('Hasil pemeriksaan', Icons.monitor_heart_outlined),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Skor kesehatan batang',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Text.rich(TextSpan(children: [
                TextSpan(text: '${data.healthScore}',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const TextSpan(text: ' / 100',
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ])),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: (data.healthScore / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: riskColor,
                  backgroundColor: AppColors.divider,
                ),
              ),
              const SizedBox(height: 22),
              const Text('Kondisi terdeteksi',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Text(_value(data.detectedCondition, 'Belum dicatat'),
                style: const TextStyle(fontSize: 15, height: 1.5,
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: AppColors.border)),
              _measurement(context, 'Luka permukaan',
                '${data.persentaseLuka.toStringAsFixed(1)}%',
                Icons.texture_rounded),
              const Padding(padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.divider)),
              _measurement(context, 'Estimasi DBH',
                '${data.diameter.toStringAsFixed(1)} cm',
                Icons.straighten_rounded),
              const Padding(padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.divider)),
              _measurement(context, 'Estimasi kemiringan',
                '${data.sudutKemiringan.toStringAsFixed(1)}°',
                Icons.architecture_rounded),
              const SizedBox(height: 16),
              const Text('Diameter dan kemiringan masih berupa estimasi.',
                style: TextStyle(fontSize: 12, height: 1.5,
                  color: AppColors.textSecondary)),
            ])),
            const SizedBox(height: 28),

            _heading('Lokasi pohon', Icons.location_on_outlined),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SelectableText(_value(data.locationAddress, 'Lokasi belum dicatat'),
                style: const TextStyle(fontSize: 15, height: 1.6,
                  color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              const Text('Koordinat',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 5),
              SelectableText(validInspectionCoordinates(data.latitude, data.longitude)
                  ? '${data.latitude!.toStringAsFixed(6)}, ${data.longitude!.toStringAsFixed(6)}'
                  : 'Belum tersedia',
                style: const TextStyle(fontSize: 13, height: 1.6,
                  color: AppColors.textPrimary)),
            ])),
            const SizedBox(height: 28),

            _heading('Informasi inspeksi', Icons.assignment_outlined),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _info('Petugas', _value(current.inspectorName, 'Belum dicatat')),
              const SizedBox(height: 18),
              _info('Rayon', _value(current.rayon, 'Belum dicatat')),
              const Padding(padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1, color: AppColors.divider)),
              _info('ID inspeksi', _value(data.inspectionId, 'Belum tersedia')),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(current.isSynced
                    ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                    size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(current.isSynced ? 'Tersinkron ke cloud' : 'Tersimpan di perangkat',
                    style: const TextStyle(fontSize: 13, height: 1.5,
                      color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                  if (!current.isSynced) ...[
                    const SizedBox(height: 3),
                    const Text('Menunggu sinkronisasi',
                      style: TextStyle(fontSize: 12, height: 1.5,
                        color: AppColors.textSecondary)),
                  ],
                ])),
              ]),
            ])),
            const SizedBox(height: 28),

            _heading('Catatan petugas', Icons.notes_rounded),
            _panel(SelectableText(_value(current.notes, 'Belum ada catatan tambahan.'),
              style: TextStyle(fontSize: 14, height: 1.7,
                color: current.notes.trim().isEmpty
                  ? AppColors.textSecondary : AppColors.textPrimary))),
          ],
        ),
      ),
    );
  }

  String _value(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();

  Widget _heading(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 19, color: AppColors.primary)),
      const SizedBox(width: 9),
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16,
        height: 1.4, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
    ]),
  );

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _measurement(BuildContext context, String label, String value, IconData icon) =>
    LayoutBuilder(builder: (context, constraints) {
      final stack = constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final labelWidget = Text(label, style: const TextStyle(
        fontSize: 13, height: 1.5, color: AppColors.textSecondary));
      final valueWidget = Text(value, style: const TextStyle(
        fontSize: 18, height: 1.4, fontWeight: FontWeight.w600,
        color: AppColors.textPrimary));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 19, color: AppColors.primary)),
        const SizedBox(width: 12),
        Expanded(child: stack
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              labelWidget, const SizedBox(height: 5), valueWidget,
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: labelWidget), const SizedBox(width: 12),
              Flexible(child: Align(alignment: Alignment.centerRight, child: valueWidget)),
            ])),
      ]);
    });

  Widget _info(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      const SizedBox(height: 5),
      SelectableText(value, style: const TextStyle(
        color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
    ],
  );
}
