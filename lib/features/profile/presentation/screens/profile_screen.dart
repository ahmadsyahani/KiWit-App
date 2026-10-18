import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
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
    if (ref.read(inspectionControllerProvider).hasError) {
      ref.invalidate(inspectionControllerProvider);
      return;
    }
    try {
      await ref.read(inspectionControllerProvider.notifier).refresh();
    } catch (_) {
      // The inspection provider exposes loading and read failures in the UI.
    }
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
      backgroundColor: profileCanvas,
      appBar: AppBar(
        backgroundColor: profileCanvas,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Profil',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ProfileAvatar(
                                name: profile.fullName,
                                avatarUrl: profile.avatarUrl,
                                dark: true,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'KiWit',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      authenticated
                                          ? 'Akun petugas'
                                          : 'Belum masuk akun',
                                      style: const TextStyle(
                                        color: Color(0xFFC7DECF),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile.jobTitle,
                            style: const TextStyle(
                              color: Color(0xFFD1E4D7),
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  authBusy ||
                                      (authenticated && profileAsync.isLoading)
                                  ? null
                                  : authenticated
                                  ? () => _editProfile(profile)
                                  : _login,
                              icon: Icon(
                                authenticated
                                    ? LucideIcons.userPen
                                    : LucideIcons.logIn,
                                size: 18,
                              ),
                              label: Text(
                                authenticated ? 'Edit profil' : 'Masuk ke akun',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                disabledBackgroundColor: const Color(
                                  0xFFDCE6DE,
                                ),
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const ProfileSectionTitle(
                      title: 'Aktivitas inspeksi',
                      subtitle: 'Ringkasan hasil inspeksi yang Anda simpan.',
                    ),
                    const SizedBox(height: 12),
                    ProfileCard(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _metric(
                                  icon: LucideIcons.trees,
                                  value: feed == null
                                      ? '—'
                                      : '${feed.records.length}',
                                  label: 'Inspeksi tersimpan',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _metric(
                                  icon: authenticated
                                      ? LucideIcons.cloudCheck
                                      : LucideIcons.smartphone,
                                  value: feed == null
                                      ? '—'
                                      : authenticated
                                      ? '${feed.records.where((record) => record.isSynced).length}'
                                      : '${feed.records.length}',
                                  label: authenticated
                                      ? 'Tersinkron'
                                      : 'Di perangkat ini',
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Divider(height: 1, color: AppColors.border),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(syncIcon, color: profileSecondary, size: 19),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      syncTitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      syncDescription,
                                      style: const TextStyle(
                                        color: profileSecondary,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (authenticated) ...[
                      const SizedBox(height: 24),
                      const ProfileSectionTitle(
                        title: 'Informasi akun',
                        subtitle: 'Identitas dan wilayah penugasan Anda.',
                      ),
                      const SizedBox(height: 12),
                      ProfileCard(
                        child: Column(
                          children: [
                            if (profileAsync.isLoading)
                              const LinearProgressIndicator(
                                minHeight: 2,
                                color: AppColors.primary,
                              ),
                            if (profileAsync.hasError)
                              const Text(
                                'Profil belum dapat diperbarui. Menampilkan informasi akun yang tersedia.',
                                style: TextStyle(
                                  color: profileSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ProfileDetail(
                              icon: LucideIcons.mail,
                              label: 'Email',
                              value: profile.email,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            ProfileDetail(
                              icon: LucideIcons.badgeCheck,
                              label: 'NIP',
                              value: profile.nip,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            ProfileDetail(
                              icon: LucideIcons.mapPin,
                              label: 'Wilayah penugasan',
                              value: profile.rayon,
                            ),
                            const Divider(height: 1, color: AppColors.border),
                            ProfileDetail(
                              icon: LucideIcons.building,
                              label: 'Instansi',
                              value: profile.instansi,
                              last: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                          minimumSize: const Size(0, 52),
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

  Widget _metric({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 21),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            color: profileSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
