import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../scan/data/repositories/inspection_controller.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
import '../../../notifications/presentation/notification_screen.dart';
import '../../../notifications/presentation/pending_sync_screen.dart';
import '../../../auth/presentation/screens/forgot_password_screen.dart';
import '../widgets/profile_components.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _showLogoutDialog({required int pendingCount}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Keluar dari KiWit?'),
        content: Text(
          pendingCount > 0
              ? 'Ada $pendingCount inspeksi yang belum tersinkron. Data tetap '
                    'tersimpan di perangkat ini dan bisa disinkronkan setelah '
                    'Anda masuk kembali dengan akun yang sama.'
              : 'Anda bisa masuk kembali untuk melanjutkan inspeksi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFAD3636),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primary : const Color(0xFFAD3636),
        content: Text(
          success
              ? 'Anda telah keluar dari akun.'
              : 'Belum berhasil keluar. Silakan coba lagi.',
        ),
      ),
    );
  }

  void _editProfile(UserProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
  }

  void _login() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(userProfileProvider);
    await refreshInspections(ref);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final inspectionAsync = ref.watch(inspectionControllerProvider);
    final authBusy = ref.watch(authControllerProvider).isLoading;
    final authenticated = user != null;
    final loadedProfile = profileAsync.valueOrNull;
    final savedProfile = authenticated && loadedProfile?.id == user.id
        ? loadedProfile
        : null;
    final metadata = user?.userMetadata;
    String metadataText(String key, String fallback) {
      final value = metadata?[key];
      return value is String && value.trim().isNotEmpty ? value : fallback;
    }

    final profile =
        savedProfile ??
        UserProfile(
          id: user?.id ?? 'guest',
          email: user?.email ?? '',
          fullName: authenticated
              ? metadataText(
                  'full_name',
                  user.email?.split('@').first ?? 'Petugas DLH',
                )
              : 'Mode tamu',
          jobTitle: authenticated
              ? metadataText('job_title', 'Petugas DLH')
              : 'Jelajahi KiWit dan mulai inspeksi pohon.',
          nip: metadataText('nip', ''),
          rayon: metadataText('rayon', ''),
          instansi: metadataText('instansi', ''),
          avatarUrl: metadataText('avatar_url', ''),
          isSync: false,
        );
    final feed = inspectionAsync.valueOrNull;
    final pending = feed?.pendingCount ?? 0;
    final String syncTitle;
    final String syncDescription;
    final IconData syncIcon;
    if (inspectionAsync.hasError) {
      syncTitle = 'Data belum dapat dimuat';
      syncDescription = 'Tarik halaman ke bawah untuk mencoba lagi.';
      syncIcon = LucideIcons.cloudOff;
    } else if (feed == null) {
      syncTitle = 'Memuat inspeksi';
      syncDescription = 'Menyiapkan ringkasan aktivitas Anda.';
      syncIcon = LucideIcons.refreshCw;
    } else if (!authenticated) {
      syncTitle = 'Disimpan di perangkat ini';
      syncDescription = 'Masuk untuk menyimpan inspeksi baru ke akun Anda.';
      syncIcon = LucideIcons.smartphone;
    } else if (feed.syncing) {
      syncTitle = 'Sedang menyinkronkan';
      syncDescription = 'Memperbarui data inspeksi akun Anda.';
      syncIcon = LucideIcons.refreshCw;
    } else if (feed.syncIssue != null || pending > 0) {
      syncTitle = pending > 0
          ? '$pending inspeksi menunggu sinkron'
          : 'Sinkronisasi tertunda';
      syncDescription =
          'Data di perangkat tetap tersedia. Tarik ke bawah untuk mencoba lagi.';
      syncIcon = LucideIcons.cloudOff;
    } else {
      syncTitle = 'Inspeksi tersinkron';
      syncDescription = 'Data inspeksi akun Anda sudah diperbarui.';
      syncIcon = LucideIcons.cloudCheck;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 20,
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (authenticated)
            IconButton(
              tooltip: 'Edit profil',
              onPressed: authBusy || profileAsync.isLoading
                  ? null
                  : () => _editProfile(profile),
              icon: const Icon(
                LucideIcons.userPen,
                size: 21,
                color: AppColors.primary,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileHeader(context, profile, feed, authenticated),
                    if (!authenticated) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: authBusy ? null : _login,
                        icon: const Icon(LucideIcons.logIn, size: 18),
                        label: const Text('Masuk ke akun'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (authenticated) ...[
                      _sectionTitle('Informasi akun'),
                      Container(
                        decoration: _cardDecoration(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Column(
                          children: [
                            if (profileAsync.isLoading)
                              const LinearProgressIndicator(minHeight: 2),
                            if (profileAsync.hasError)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Profil belum dapat diperbarui. Menampilkan informasi akun yang tersedia.',
                                  style: TextStyle(
                                    color: profileSecondary,
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            _accountRow('NIP', profile.nip),
                            _accountRow('Rayon', profile.rayon),
                            _accountRow('Instansi', profile.instansi),
                            _accountRow('Email', profile.email, last: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                    _sectionTitle('Aktivitas dan keamanan'),
                    Container(
                      decoration: _cardDecoration(),
                      child: Column(
                        children: [
                          _actionTile(
                            icon: LucideIcons.bell,
                            title: 'Notifikasi inspeksi',
                            subtitle: 'Risiko dan pembaruan laporan',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const NotificationScreen(),
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            indent: 60,
                            endIndent: 16,
                            color: AppColors.border,
                          ),
                          _actionTile(
                            icon: syncIcon,
                            title: syncTitle,
                            subtitle: syncDescription,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const PendingSyncScreen(),
                              ),
                            ),
                          ),
                          if (authenticated) ...[
                            const Divider(
                              height: 1,
                              indent: 60,
                              endIndent: 16,
                              color: AppColors.border,
                            ),
                            _actionTile(
                              icon: LucideIcons.lockKeyhole,
                              title: 'Atur ulang kata sandi',
                              subtitle: 'Kirim tautan pemulihan melalui email',
                              onTap: authBusy
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (feed?.recoveryIssue case final String issue)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          issue,
                          style: const TextStyle(
                            color: AppColors.riskHighText,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (authenticated) ...[
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: authBusy
                            ? null
                            : () => _showLogoutDialog(pendingCount: pending),
                        icon: const Icon(LucideIcons.logOut, size: 18),
                        label: Text(
                          authBusy ? 'Mohon tunggu...' : 'Keluar dari akun',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFAD3636),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context,
    UserProfile profile,
    InspectionFeed? feed,
    bool authenticated,
  ) {
    final stacked = MediaQuery.textScalerOf(context).scale(22) > 32;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(
                name: profile.fullName,
                avatarUrl: profile.avatarUrl,
                circular: true,
                dark: true,
              ),
              const SizedBox(width: 14, height: 14),
              Flexible(
                flex: stacked ? 0 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.jobTitle,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white38),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  value: feed?.records.length,
                  label: authenticated
                      ? 'Inspeksi tersimpan'
                      : 'Inspeksi di perangkat ini',
                ),
              ),
              if (authenticated) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _metric(
                    value: feed == null
                        ? null
                        : feed.records.length - feed.pendingCount,
                    label: 'Tersinkron',
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _metric({required int? value, required String label}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value?.toString() ?? '...',
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.15,
          color: Colors.white,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.5,
          color: AppColors.primaryLight,
        ),
      ),
    ],
  );

  Widget _accountRow(String label, String value, {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(12) > 16;
            final labelWidget = Text(
              label,
              style: const TextStyle(fontSize: 13, color: profileSecondary),
            );
            final valueWidget = Text(
              value.trim().isEmpty || value == '-' ? 'Belum diisi' : value,
              textAlign: stacked ? TextAlign.start : TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelWidget,
                      const SizedBox(height: 5),
                      valueWidget,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: labelWidget),
                      const SizedBox(width: 12),
                      Expanded(flex: 5, child: valueWidget),
                    ],
                  );
          },
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 34,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: profileSecondary,
          ),
        ),
      ),
      trailing: const Icon(
        LucideIcons.chevronRight,
        size: 17,
        color: profileSecondary,
      ),
      onTap: onTap,
    ),
  );
}
