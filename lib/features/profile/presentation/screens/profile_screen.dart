import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import 'edit_profile_screen.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationEnabled = true;

  Future<void> _showLogoutDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari sesi akun Petugas DLH saat ini?',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Anda telah berhasil keluar dari akun.'),
          ),
        );
      }
    }
  }

  void _navigateToEditProfile(UserProfile currentProfile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(profile: currentProfile),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final bool isAuthenticated = user != null;

    // Extract dynamic display name and values with high priority from Supabase
    final String displayName = profileAsync.value?.fullName ??
        (user?.userMetadata?['full_name'] as String?) ??
        (user != null ? (user.email?.split('@').first ?? 'Petugas DLH') : 'Petugas DLH (Tamu)');

    final String jobTitle = profileAsync.value?.jobTitle ??
        (user?.userMetadata?['job_title'] as String?) ??
        (isAuthenticated ? 'Petugas Lapangan DLH Kota Surabaya' : 'Mode Eksplorasi Tamu');

    final String nip = profileAsync.value?.nip ??
        (user?.userMetadata?['nip'] as String?) ??
        '-';

    final String rayon = profileAsync.value?.rayon ??
        (user?.userMetadata?['rayon'] as String?) ??
        'Rayon 3 — Sukolilo';

    final String instansi = profileAsync.value?.instansi ??
        (user?.userMetadata?['instansi'] as String?) ??
        'DLH Kota Surabaya';

    final String email = profileAsync.value?.email ?? user?.email ?? '-';

    final int inspectedTrees = profileAsync.value?.inspectedTreesCount ?? 0;
    final int reportsCount = profileAsync.value?.reportsCount ?? 0;

    final profile = profileAsync.value ??
        UserProfile(
          id: user?.id ?? 'guest',
          email: email,
          fullName: displayName,
          jobTitle: jobTitle,
          nip: nip,
          rayon: rayon,
          instansi: instansi,
          inspectedTreesCount: inspectedTrees,
          reportsCount: reportsCount,
          isSync: isAuthenticated,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(LucideIcons.chevronLeft, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'Profil',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (isAuthenticated)
            IconButton(
              icon: const Icon(LucideIcons.userPen, color: AppColors.primary),
              tooltip: 'Edit Profil',
              onPressed: () => _navigateToEditProfile(profile),
            ),

        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 1. Status Banner: ONLY shown when user is NOT authenticated
            if (!isAuthenticated)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.logIn, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belum Masuk Akun',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Masuk untuk sinkronisasi data inspeksi',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('Masuk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              // Verified Officer Badge when Logged In
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(LucideIcons.badgeCheck, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Akun Petugas DLH Terverifikasi & Tersinkron',
                      style: TextStyle(color: AppColors.primaryDark, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Avatar
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.user,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic User Full Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Dynamic Job Title
            Text(
              jobTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$inspectedTrees',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pohon Diinspeksi',
                            style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$reportsCount',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Laporan',
                            style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Informasi Akun
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Informasi Akun', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      if (isAuthenticated)
                        GestureDetector(
                          onTap: () => _navigateToEditProfile(profile),
                          child: const Text('Ubah', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),

                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Email', email),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInfoRow('NIP', nip),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInfoRow('Rayon', rayon),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInfoRow('Instansi', instansi),
                  const Divider(color: AppColors.border, height: 24),
                  _buildInfoRow(
                    'Status Sync',
                    isAuthenticated ? 'Tersinkron ✓' : 'Lokal (Guest)',
                    isSync: isAuthenticated,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Preferensi & Keamanan
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Preferensi & Keamanan', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildSettingItem(
                    icon: LucideIcons.bell,
                    title: 'Notifikasi Laporan',
                    subtitle: 'Aktifkan ketika menerima laporan',
                    trailing: Switch(
                      value: _notificationEnabled,
                      onChanged: (val) => setState(() => _notificationEnabled = val),
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildSettingItem(
                    icon: LucideIcons.lock,
                    title: 'Account & Password',
                    subtitle: isAuthenticated ? 'Kelola data & kredensial' : 'Masuk untuk mengelola kredensial',
                    onTap: () {
                      if (!isAuthenticated) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      } else {
                        _navigateToEditProfile(profile);
                      }
                    },

                    trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 20),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildSettingItem(
                    icon: LucideIcons.settings,
                    title: 'Pengaturan Sistem',
                    subtitle: 'Pengaturan server Supabase & geolokasi',
                    trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 20),
                  ),
                  if (isAuthenticated) ...[
                    const Divider(color: AppColors.border, height: 1),
                    _buildSettingItem(
                      icon: LucideIcons.logOut,
                      title: 'Keluar Akun',
                      subtitle: 'Keluar dari sesi petugas saat ini',
                      iconColor: Colors.red.shade600,
                      iconBgColor: Colors.red.shade50,
                      onTap: _showLogoutDialog,
                      trailing: const Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 20),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 100), // padding for navbar
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSync = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isSync ? AppColors.primary : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: isSync ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    Color iconColor = AppColors.primary,
    Color iconBgColor = AppColors.primaryLight,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}