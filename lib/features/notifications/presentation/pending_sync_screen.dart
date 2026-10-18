import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../scan/presentation/providers/inspection_providers.dart';
import '../../scan/presentation/screens/saved_inspection_detail_screen.dart';

Future<void> refreshNotificationInspections(WidgetRef ref) async {
  if (ref.read(inspectionControllerProvider).hasError) {
    ref.invalidate(inspectionControllerProvider);
    return;
  }
  try {
    await ref.read(inspectionControllerProvider.notifier).refresh();
  } catch (_) {
    // The shared feed exposes the failure and preserves local inspections.
  }
}

class PendingSyncScreen extends ConsumerWidget {
  const PendingSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(inspectionControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Sinkronisasi inspeksi')),
      body: source.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, stack) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Data inspeksi belum dapat dibaca.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(inspectionControllerProvider),
              child: const Text('Coba lagi')),
          ]),
        )),
        data: (feed) {
          final pending = feed.records.where((record) => !record.isSynced).toList();
          return RefreshIndicator(
            onRefresh: () => refreshNotificationInspections(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(feed.syncing ? Icons.cloud_sync_outlined :
                      (pending.isEmpty && feed.syncIssue == null
                        ? Icons.cloud_done_outlined : Icons.cloud_off_outlined),
                      color: AppColors.primary, size: 30),
                    const SizedBox(height: 14),
                    Text(feed.syncing ? 'Menyinkronkan inspeksi…' :
                      pending.isEmpty ? (feed.syncIssue == null
                        ? 'Data sudah tersinkron' : 'Koneksi perlu diperiksa') :
                        '${pending.length} inspeksi menunggu sinkronisasi',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark)),
                    const SizedBox(height: 8),
                    Text(feed.syncIssue ?? (pending.isEmpty
                      ? 'Inspeksi pada akun ini sudah diperbarui.'
                      : 'Foto dan hasil inspeksi tetap tersimpan di perangkat ini.'),
                      style: const TextStyle(height: 1.5, color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: feed.syncing ? null : () => refreshNotificationInspections(ref),
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: const Text('Sinkronkan sekarang')),
                  ]),
                ),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Inspeksi tertunda',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  ...pending.map((record) => Card(
                    elevation: 0,
                    color: AppColors.surface,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: const Icon(Icons.park_outlined, color: AppColors.primary),
                      title: Text(record.data.treeSpecies, maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(record.data.locationAddress.isEmpty ? 'Lokasi belum dicatat' :
                        record.data.locationAddress, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => SavedInspectionDetailScreen(record: record))),
                    ),
                  )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
