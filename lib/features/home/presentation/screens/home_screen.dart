import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../scan/data/repositories/inspection_controller.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
import '../widgets/home_header.dart';
import '../widgets/hero_banner_card.dart';
import '../widgets/inspection_chart_card.dart';
import '../widgets/recent_inspection_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  DateTime _today = DateTime.now();
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextDay();
  }

  void _scheduleNextDay() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(nextDay.difference(now), () {
      if (!mounted) return;
      setState(() => _today = DateTime.now());
      _scheduleNextDay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _today = DateTime.now());
      _scheduleNextDay();
      unawaited(_refreshInspections());
    } else {
      _dayTimer?.cancel();
    }
  }

  Future<void> _refreshInspections() async {
    if (ref.read(inspectionControllerProvider).hasError) {
      ref.invalidate(inspectionControllerProvider);
      return;
    }
    try {
      await ref.read(inspectionControllerProvider.notifier).refresh();
    } catch (_) {
      // A local read failure is already visible through the provider error state.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  Widget _syncStatus(InspectionFeed feed) {
    final String message;
    if (feed.syncing) {
      message = 'Menyinkronkan inspeksi...';
    } else if (feed.syncIssue != null) {
      message = feed.syncIssue!;
    } else if (feed.pendingCount > 0) {
      message = '${feed.pendingCount} inspeksi menunggu sinkronisasi.';
    } else {
      message = 'Data inspeksi tersinkron.';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            feed.syncIssue != null ? Icons.cloud_off_outlined : Icons.cloud_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
          ),
          if (!feed.syncing && feed.syncIssue != null)
            TextButton(onPressed: _refreshInspections, child: const Text('Coba lagi')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspections = ref.watch(inspectionControllerProvider);
    final inspectionWidgets = inspections.when<List<Widget>>(
      data: (feed) => [
        if (feed.records.isNotEmpty || feed.syncIssue != null || feed.syncing) ...[
          _syncStatus(feed),
          const SizedBox(height: 16),
        ],
        InspectionChartCard(records: feed.records, today: _today),
        const SizedBox(height: 24),
        RecentInspectionList(records: feed.records),
      ],
      loading: () => [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
      error: (error, stackTrace) => [
        const Text('Data inspeksi belum dapat dibaca.', style: TextStyle(color: AppColors.textSecondary)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => ref.invalidate(inspectionControllerProvider),
            child: const Text('Coba lagi'),
          ),
        ),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshInspections,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              const HomeHeader(),
              const SizedBox(height: 24),
              const HeroBannerCard(),
              const SizedBox(height: 24),
              ...inspectionWidgets,
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
