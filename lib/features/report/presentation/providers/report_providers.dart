import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';

enum ReportPeriod { currentMonth, allTime, customMonth, customYear }

enum ReportFilter {
  all('Semua'),
  critical('Kritis'),
  high('Tinggi'),
  medium('Sedang'),
  low('Rendah'),
  pending('Belum sinkron');

  const ReportFilter(this.label);
  final String label;
}

final reportNowProvider = StateProvider<DateTime>((ref) => DateTime.now());

final reportPeriodProvider = StateProvider<ReportPeriod>((ref) {
  ref.watch(currentUserIdProvider);
  return ReportPeriod.currentMonth;
});

final reportCustomDateProvider = StateProvider<DateTime>((ref) {
  ref.watch(currentUserIdProvider);
  final now = ref.read(reportNowProvider).toLocal();
  return DateTime(now.year, now.month);
});

final reportFilterProvider = StateProvider<ReportFilter>((ref) {
  ref.watch(currentUserIdProvider);
  return ReportFilter.all;
});

final reportSearchProvider = StateProvider<String>((ref) {
  ref.watch(currentUserIdProvider);
  return '';
});

class ReportData {
  ReportData({
    required List<SavedInspection> periodRecords,
    required List<SavedInspection> visibleRecords,
    required this.totalStored,
  }) : periodRecords = List.unmodifiable(periodRecords),
       visibleRecords = List.unmodifiable(visibleRecords);

  final List<SavedInspection> periodRecords;
  final List<SavedInspection> visibleRecords;
  final int totalStored;

  int get inspectedCount => periodRecords.length;
  int get criticalCount =>
      periodRecords.where((r) => r.riskLevel == RiskLevel.kritis).length;
  int get highCount =>
      periodRecords.where((r) => r.riskLevel == RiskLevel.tinggi).length;
  int get pendingCount => periodRecords.where((r) => !r.isSynced).length;
}

ReportData projectReportData(
  List<SavedInspection> records, {
  required DateTime now,
  ReportPeriod period = ReportPeriod.currentMonth,
  DateTime? customDate,
  ReportFilter filter = ReportFilter.all,
  String query = '',
}) {
  final target = period == ReportPeriod.customMonth || period == ReportPeriod.customYear
      ? (customDate ?? now).toLocal() : now.toLocal();
  final periodRecords = records.where((record) {
    if (period == ReportPeriod.allTime) return true;
    final date = record.data.scanTimestamp.toLocal();
    return date.year == target.year &&
        (period == ReportPeriod.customYear || date.month == target.month);
  }).toList()
    ..sort((a, b) {
      final date = b.data.scanTimestamp.compareTo(a.data.scanTimestamp);
      return date != 0 ? date : a.id.compareTo(b.id);
    });
  final needle = query.trim().toLowerCase();
  final visible = periodRecords.where((record) {
    final matchesRisk = switch (filter) {
      ReportFilter.all => true,
      ReportFilter.critical => record.riskLevel == RiskLevel.kritis,
      ReportFilter.high => record.riskLevel == RiskLevel.tinggi,
      ReportFilter.medium => record.riskLevel == RiskLevel.sedang,
      ReportFilter.low => record.riskLevel == RiskLevel.rendah,
      ReportFilter.pending => !record.isSynced,
    };
    return matchesRisk && (needle.isEmpty || [
      record.data.treeSpecies,
      record.data.inspectionId,
      record.data.locationAddress,
    ].any((value) => value.toLowerCase().contains(needle)));
  }).toList();
  return ReportData(
    periodRecords: periodRecords,
    visibleRecords: visible,
    totalStored: records.length,
  );
}

final reportDataProvider = Provider<AsyncValue<ReportData>>((ref) {
  final feed = ref.watch(inspectionControllerProvider);
  final now = ref.watch(reportNowProvider);
  final period = ref.watch(reportPeriodProvider);
  final customDate = ref.watch(reportCustomDateProvider);
  final filter = ref.watch(reportFilterProvider);
  final query = ref.watch(reportSearchProvider);
  return feed.whenData((value) => projectReportData(
    value.records, now: now, period: period, customDate: customDate,
    filter: filter, query: query,
  ));
});

String reportPeriodLabel(ReportPeriod period, DateTime now, DateTime customDate) =>
    switch (period) {
      ReportPeriod.currentMonth => reportMonthLabel(now),
      ReportPeriod.allTime => 'Semua waktu',
      ReportPeriod.customMonth => reportMonthLabel(customDate),
      ReportPeriod.customYear => 'Tahun ${customDate.year}',
    };

String reportMonthLabel(DateTime date) {
  const names = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final local = date.toLocal();
  return '${names[local.month - 1]} ${local.year}';
}
