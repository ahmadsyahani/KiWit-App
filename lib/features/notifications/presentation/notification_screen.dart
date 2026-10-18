import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../scan/data/models/saved_inspection.dart';
import '../../scan/presentation/providers/inspection_providers.dart';
import '../../scan/presentation/screens/saved_inspection_detail_screen.dart';
import '../data/notification_entry.dart';
import 'notification_controller.dart';
import 'pending_sync_screen.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});
  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen>
    with WidgetsBindingObserver {
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDay();
  }

  void _scheduleDay() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    _dayTimer = Timer(DateTime(now.year, now.month, now.day + 1).difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleDay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDay();
      unawaited(refreshNotificationInspections(ref));
    } else {
      _dayTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _open(NotificationEntry entry) async {
    await ref.read(notificationControllerProvider.notifier).markRead(entry.id);
    if (!mounted) return;
    if (entry.kind != NotificationKind.risk) {
      await Navigator.push(context, MaterialPageRoute<void>(
        builder: (_) => const PendingSyncScreen()));
      return;
    }
    final records = ref.read(inspectionControllerProvider).valueOrNull?.records ?? [];
    for (final record in records) {
      if (record.id == entry.recordId) {
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => SavedInspectionDetailScreen(record: record)));
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inspeksi ini belum tersedia. Coba perbarui data.')));
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(notificationControllerProvider);
    final source = ref.watch(inspectionControllerProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recent = inbox.entries.where((entry) =>
      !entry.createdAt.toLocal().isBefore(today)).toList();
    final earlier = inbox.entries.where((entry) =>
      entry.createdAt.toLocal().isBefore(today)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifikasi')),
      body: RefreshIndicator(
        onRefresh: () async {
          await refreshNotificationInspections(ref);
          if (mounted && ref.read(notificationControllerProvider).storageIssue != null) {
            final feed = ref.read(inspectionControllerProvider).valueOrNull;
            if (feed != null) await ref.read(notificationControllerProvider.notifier).receive(feed);
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(inbox.loading ? 'Memuat pemberitahuan…' :
                    inbox.entries.isEmpty ? 'Pemberitahuan untuk inspeksi Anda' : inbox.unreadCount == 0
                    ? 'Semua pemberitahuan sudah dibaca'
                    : '${inbox.unreadCount} pemberitahuan belum dibaca',
                    style: const TextStyle(fontSize: 14, height: 1.5,
                      color: AppColors.textSecondary))),
                  if (inbox.unreadCount > 0) ...[
                    const SizedBox(width: 12),
                    Flexible(child: TextButton(
                      onPressed: () => ref.read(notificationControllerProvider.notifier).markAllRead(),
                      child: const Text('Tandai semua dibaca', textAlign: TextAlign.end))),
                  ],
                ]),
                if (inbox.storageIssue != null || source.hasError) ...[
                  const SizedBox(height: 12),
                  Text(inbox.storageIssue ?? 'Data inspeksi belum dapat diperbarui. Tarik ke bawah untuk mencoba lagi.',
                    style: const TextStyle(color: AppColors.riskHighText, height: 1.5)),
                ],
              ]),
            )),
            if (inbox.loading || (source.isLoading && inbox.entries.isEmpty))
              const SliverFillRemaining(hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()))
            else if (inbox.entries.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 80),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_none_rounded, size: 38, color: AppColors.primary)),
                  const SizedBox(height: 22),
                  Text(source.hasError ? 'Data belum tersedia' : 'Belum ada notifikasi',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  const Text('Pemberitahuan inspeksi berisiko dan status sinkronisasi akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
                ]),
              ))
            else ...[
              if (recent.isNotEmpty) ..._section('Hari ini', recent, true),
              if (earlier.isNotEmpty) ..._section('Sebelumnya', earlier, false),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _section(String title, List<NotificationEntry> entries, bool today) => [
    SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)))),
    SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) => _tile(entries[index], today),
    ),
  ];

  Widget _tile(NotificationEntry entry, bool today) {
    final risk = entry.kind == NotificationKind.risk;
    final critical = risk && entry.id.endsWith(':kritis');
    final success = entry.kind == NotificationKind.syncComplete;
    final color = critical ? AppColors.riskCriticalText :
      risk ? AppColors.riskHighText : AppColors.primary;
    final time = entry.createdAt.toLocal();
    final clock = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: entry.isRead ? AppColors.surface : const Color(0xFFF0F6F2),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(entry),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: critical ? AppColors.riskCriticalBg :
                  risk ? AppColors.riskHighBg :
                  AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Icon(risk ? Icons.priority_high_rounded :
                  success ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(entry.title, style: TextStyle(
                    fontSize: 14, height: 1.4,
                    fontWeight: entry.isRead ? FontWeight.w500 : FontWeight.w700))),
                  if (!entry.isRead) Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6),
                    child: Container(width: 7, height: 7,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))),
                ]),
                const SizedBox(height: 5),
                Text(entry.message, style: const TextStyle(fontSize: 12,
                  height: 1.6, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Text(today ? clock : '${formatInspectionDate(time)} · $clock',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}
