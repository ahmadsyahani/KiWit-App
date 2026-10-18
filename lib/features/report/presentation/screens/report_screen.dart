import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../scan/data/repositories/inspection_controller.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
import '../../../scan/presentation/screens/saved_inspection_detail_screen.dart';
import '../../../scan/presentation/screens/scan_screen.dart';
import '../providers/report_providers.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/report_tree_card.dart';
import '../widgets/report_period_sheet.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  Timer? _dateTimer;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextDay();
  }

  void _scheduleNextDay() {
    _dateTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _dateTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      ref.read(reportNowProvider.notifier).state = DateTime.now();
      _scheduleNextDay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(reportNowProvider.notifier).state = DateTime.now();
      _scheduleNextDay();
      unawaited(_refresh());
    } else {
      _dateTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (ref.read(inspectionControllerProvider).hasError) {
      ref.invalidate(inspectionControllerProvider);
    }
    try {
      await ref.read(inspectionControllerProvider.notifier).refresh();
    } catch (_) {
      // Local read errors and cloud sync issues are shown by the shared feed.
    }
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(reportSearchProvider.notifier).state = '';
    ref.read(reportFilterProvider.notifier).state = ReportFilter.all;
  }

  void _toggleSearch() {
    if (_showSearch) {
      _searchController.clear();
      ref.read(reportSearchProvider.notifier).state = '';
      FocusScope.of(context).unfocus();
    }
    setState(() => _showSearch = !_showSearch);
  }

  Future<void> _choosePeriod() async {
    FocusScope.of(context).unfocus();
    final account = ref.read(currentUserIdProvider);
    final selection = await showModalBottomSheet<(ReportPeriod, DateTime)>(
      context: context, useSafeArea: true, showDragHandle: true, isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => ReportPeriodSheet(
        period: ref.read(reportPeriodProvider),
        customDate: ref.read(reportCustomDateProvider),
        now: ref.read(reportNowProvider),
      ),
    );
    if (!mounted || selection == null || account != ref.read(currentUserIdProvider)) return;
    ref.read(reportCustomDateProvider.notifier).state = selection.$2;
    ref.read(reportPeriodProvider.notifier).state = selection.$1;
  }

  void _startScan() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(inspectionControllerProvider);
    final dataAsync = ref.watch(reportDataProvider);
    final period = ref.watch(reportPeriodProvider);
    final filter = ref.watch(reportFilterProvider);
    final query = ref.watch(reportSearchProvider);
    final hasFilters = filter != ReportFilter.all || query.trim().isNotEmpty;
    final now = ref.watch(reportNowProvider);
    final customDate = ref.watch(reportCustomDateProvider);
    final periodLabel = reportPeriodLabel(period, now, customDate);
    final guest = ref.watch(currentUserIdProvider) == null;
    final data = dataAsync.valueOrNull;
    final feed = feedAsync.valueOrNull;
    final unresolvedCloud = !guest && feed != null && feed.records.isEmpty &&
        (feed.syncing || feed.syncIssue != null);
    final summaryLoading = data == null || dataAsync.hasError || unresolvedCloud;

    ref.listen(currentUserIdProvider, (_, _) {
      _searchController.clear();
      if (_showSearch) setState(() => _showSearch = false);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700,
        )),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,

      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(guest ? 'Inspeksi perangkat ini' : 'Riwayat inspeksi Anda',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF5C7064))),
                          const SizedBox(height: 14),
                          MonthlySummaryCard(
                            inspectedCount: data?.inspectedCount ?? 0,
                            criticalCount: data?.criticalCount ?? 0,
                            highCount: data?.highCount ?? 0,
                            pendingSyncCount: data?.pendingCount ?? 0,
                            periodLabel: period == ReportPeriod.currentMonth ? 'Bulan ini' : periodLabel,
                            loading: summaryLoading,
                          ),
                          const SizedBox(height: 12),
                          if (feed != null) _syncStatus(feed, guest),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(child: Text('Daftar inspeksi', style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                              ))),
                              if (!summaryLoading)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF4EF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('${data.visibleRecords.length} hasil',
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                                ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: _showSearch ? 'Tutup pencarian' : 'Cari laporan',
                                onPressed: _toggleSearch,
                                icon: Icon(_showSearch ? LucideIcons.x : LucideIcons.search,
                                  size: 20, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8, runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _choosePeriod,
                                icon: const Icon(LucideIcons.calendarDays, size: 16),
                                label: Text(periodLabel,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  backgroundColor: const Color(0xFFEEF4EF),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              if (hasFilters)
                                TextButton.icon(
                                  onPressed: _clearFilters,
                                  icon: const Icon(LucideIcons.rotateCcw, size: 14),
                                  label: const Text('Reset filter', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF5C7064)),
                                ),
                            ],
                          ),
                          if (_showSearch) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _searchController,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: (value) => ref.read(reportSearchProvider.notifier).state = value,
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                hintText: 'Cari jenis, kode, atau jalan...',
                                hintStyle: const TextStyle(fontSize: 13),
                                prefixIcon: const Icon(LucideIcons.search, size: 18),
                                filled: true, fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFDCE6DE))),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: ReportFilter.values.map((value) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(value.label, style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: filter == value ? Colors.white : const Color(0xFF5C7064),
                                )),
                                selected: filter == value,
                                showCheckmark: false,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: filter == value
                                    ? AppColors.primary : const Color(0xFFDCE6DE)),
                                onSelected: (_) => ref.read(reportFilterProvider.notifier).state = value,
                              ),
                            )).toList()),
                          ),
                          const SizedBox(height: 16),
                          if (dataAsync.hasError)
                            _message(
                              LucideIcons.cloudOff, 'Laporan belum dapat dimuat',
                              'Coba muat ulang data inspeksi yang tersimpan.',
                              action: 'Coba lagi', onAction: () => unawaited(_refresh()),
                            )
                          else if (data == null || (unresolvedCloud && feed.syncing))
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          else if (unresolvedCloud)
                            _message(
                              LucideIcons.cloudOff, 'Data cloud belum dapat dimuat',
                              'Belum ada salinan inspeksi di perangkat ini. Coba lagi saat terhubung.',
                              action: 'Muat ulang', onAction: () => unawaited(_refresh()),
                            )
                          else if (data.visibleRecords.isEmpty)
                            _emptyMessage(data, period),
                        ],
                      ),
                    ),
                  ),
                  if (data != null && !dataAsync.hasError)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: data.visibleRecords.length,
                        itemBuilder: (context, index) {
                          final record = data.visibleRecords[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: ReportTreeCard(
                              record: record,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => SavedInspectionDetailScreen(record: record),
                              )),
                            ),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _syncStatus(InspectionFeed feed, bool guest) {
    final String text;
    final IconData icon;
    if (guest) {
      text = 'Data tamu tersimpan di perangkat ini.';
      icon = LucideIcons.smartphone;
    } else if (feed.syncing) {
      text = 'Menyinkronkan inspeksi...';
      icon = LucideIcons.refreshCw;
    } else if (feed.syncIssue != null) {
      text = 'Sinkronisasi tertunda. Data perangkat tetap ditampilkan.';
      icon = LucideIcons.cloudOff;
    } else if (feed.pendingCount > 0) {
      text = '${feed.pendingCount} inspeksi menunggu sinkronisasi.';
      icon = LucideIcons.cloudUpload;
    } else {
      text = 'Data inspeksi sudah diperbarui.';
      icon = LucideIcons.cloudCheck;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: const Color(0xFF5C7064)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(
          fontSize: 11, color: Color(0xFF5C7064), height: 1.5,
        ))),
      ],
    );
  }

  Widget _emptyMessage(ReportData data, ReportPeriod period) {
    if (data.totalStored == 0) {
      return _message(
        LucideIcons.clipboardList, 'Belum ada laporan inspeksi',
        'Hasil inspeksi yang Anda simpan akan tampil di sini.',
        action: 'Mulai inspeksi', onAction: _startScan,
      );
    }
    if (data.inspectedCount == 0 && period == ReportPeriod.currentMonth) {
      return _message(
        LucideIcons.calendarDays, 'Belum ada inspeksi bulan ini',
        'Anda masih bisa membuka laporan yang tersimpan pada bulan sebelumnya.',
        action: 'Lihat semua waktu',
        onAction: () => ref.read(reportPeriodProvider.notifier).state = ReportPeriod.allTime,
      );
    }
    if (data.inspectedCount == 0 && period != ReportPeriod.allTime) {
      final label = reportPeriodLabel(period, ref.read(reportNowProvider),
        ref.read(reportCustomDateProvider));
      return _message(
        LucideIcons.calendarDays, 'Belum ada inspeksi pada periode ini',
        'Tidak ada inspeksi tersimpan untuk $label.',
        action: 'Ubah periode', onAction: _choosePeriod,
      );
    }
    return _message(
      LucideIcons.search, 'Tidak ada laporan yang cocok',
      'Coba ubah tingkat risiko atau kata kunci pencarian.',
      action: 'Hapus filter', onAction: _clearFilters,
    );
  }

  Widget _message(
    IconData icon, String title, String description, {
    required String action,
    required VoidCallback onAction,
  }) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE1E8E2)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 30, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        Text(description, textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 12, height: 1.6, color: Color(0xFF5C7064),
        )),
        const SizedBox(height: 12),
        TextButton(onPressed: onAction, child: Text(action)),
      ],
    ),
  );
}
