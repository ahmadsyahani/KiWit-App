import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nipController;
  late String _selectedRayon;
  late String _selectedJobTitle;

  // Daftar Pilihan Rayon DLH Kota Surabaya (Terurut dari Rayon 1 s/d Rayon 6)
  final List<Map<String, String>> _rayonOptions = [
    {
      'code': 'R1',
      'title': 'Rayon 1 — Genteng (Surabaya Pusat)',
      'region': 'Surabaya Pusat',
      'desc': 'Genteng, Tegalsari, Bubutan, Simokerto',
    },
    {
      'code': 'R2',
      'title': 'Rayon 2 — Rungkut (Surabaya Timur)',
      'region': 'Surabaya Timur',
      'desc': 'Rungkut, Gunung Anyar, Tambaksari',
    },
    {
      'code': 'R3',
      'title': 'Rayon 3 — Sukolilo (Surabaya Timur II)',
      'region': 'Surabaya Timur II',
      'desc': 'Sukolilo, Mulyorejo, Gubeng, Tenggilis Mejoyo',
    },
    {
      'code': 'R4',
      'title': 'Rayon 4 — Sawahan (Surabaya Selatan)',
      'region': 'Surabaya Selatan',
      'desc': 'Sawahan, Wonokromo, Jambangan, Gayungan, Karangpilang',
    },
    {
      'code': 'R5',
      'title': 'Rayon 5 — Tandes (Surabaya Barat)',
      'region': 'Surabaya Barat',
      'desc': 'Tandes, Benowo, Pakal, Sambikerep, Lakarsantri, Asemrowo',
    },
    {
      'code': 'R6',
      'title': 'Rayon 6 — Kenjeran (Surabaya Utara)',
      'region': 'Surabaya Utara',
      'desc': 'Kenjeran, Bulak, Semampir, Pabean Cantian, Krembangan',
    },
  ];

  // Daftar Pilihan Jabatan Petugas DLH
  final List<String> _jobTitleOptions = [
    'Petugas Lapangan DLH Surabaya',
    'Surveyor Risiko Pohon ISA-TRAQ',
    'Tim Tanggap Darurat Pohon Tumbang',
    'Koordinator Lapangan Rayon',
    'Pengawas RTH & Hutan Kota',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _nipController = TextEditingController(text: widget.profile.nip);

    // Normalize matching rayon
    final existingRayon = widget.profile.rayon;
    final matchedRayon = _rayonOptions.firstWhere(
      (r) =>
          r['title'] == existingRayon ||
          existingRayon.contains(r['code']!) ||
          existingRayon.contains(r['title']!.split(' — ')[0]),
      orElse: () => _rayonOptions[2], // Default Rayon 3
    );
    _selectedRayon = matchedRayon['title']!;

    // Normalize matching job title
    if (_jobTitleOptions.contains(widget.profile.jobTitle)) {
      _selectedJobTitle = widget.profile.jobTitle;
    } else {
      _selectedJobTitle = _jobTitleOptions[0];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nipController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.profile.copyWith(
      fullName: _nameController.text.trim(),
      nip: _nipController.text.trim(),
      rayon: _selectedRayon,
      jobTitle: _selectedJobTitle,
    );

    final success = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(updated);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Profil Petugas berhasil diperbarui!'),
              ],
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Gagal menyimpan perubahan ke database.'),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.chevronLeft,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil Petugas',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Header
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
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
                          size: 48,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.camera,
                            color: AppColors.primary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Identitas Resmi Petugas DLH Surabaya',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Card 1: Data Pokok
                _buildSectionCard(
                  title: 'Data Pokok Petugas',
                  icon: LucideIcons.userCheck,
                  children: [
                    const Text(
                      'Nama Lengkap & Gelar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        'Contoh: Ahmad Syahani, S.Hut',
                        LucideIcons.user,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Nama lengkap wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'NIP / Nomor Induk Pegawai',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nipController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        '19850312 201001 1 004',
                        LucideIcons.badgeCheck,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'NIP wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Jabatan / Posisi Tugas',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedJobTitle,
                      isExpanded: true,
                      decoration: _inputDecoration('', LucideIcons.briefcase),
                      items: _jobTitleOptions.map((job) {
                        return DropdownMenuItem<String>(
                          value: job,
                          child: Text(
                            job,
                            style: const TextStyle(fontSize: 13.5),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedJobTitle = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Card 2: Wilayah Penugasan (Rayon 1 - 6 Terurut Rapi)
                _buildSectionCard(
                  title: 'Wilayah Penugasan (Rayon DLH)',
                  icon: LucideIcons.mapPin,
                  children: [
                    const Text(
                      'Pilih Rayon Operasional Penugasan:',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // List Kartu Rayon Terurut Rapi
                    ..._rayonOptions.map((rayon) {
                      final isSelected = _selectedRayon == rayon['title'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedRayon = rayon['title']!);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 1.8 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.08),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Badge Nomor Rayon (R1, R2, dll)
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      rayon['code']!,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Informasi Rayon
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rayon['title']!,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: isSelected
                                              ? AppColors.primaryDark
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        rayon['desc']!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isSelected
                                              ? AppColors.primaryDark.withValues(alpha: 0.7)
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Radio Icon
                                Icon(
                                  isSelected
                                      ? LucideIcons.circleCheck
                                      : LucideIcons.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // Card 3: Instansi & Akun
                _buildSectionCard(
                  title: 'Instansi & Akun',
                  icon: LucideIcons.building,
                  children: [
                    const Text(
                      'Instansi Kedinasan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: widget.profile.instansi,
                      readOnly: true,
                      decoration: _inputDecoration('', LucideIcons.landmark).copyWith(
                        fillColor: AppColors.border.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Email Terdaftar (Tidak Dapat Diubah)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: widget.profile.email,
                      readOnly: true,
                      decoration: _inputDecoration('', LucideIcons.mail).copyWith(
                        fillColor: AppColors.border.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Bottom Save CTA
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan Perubahan Profil',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
