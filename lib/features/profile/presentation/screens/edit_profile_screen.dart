import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/data/models/user_profile.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../widgets/profile_components.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nipController;
  String? _selectedRayon;
  String? _selectedJobTitle;
  bool _saving = false;

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
    _nipController = TextEditingController(
      text: widget.profile.nip == '-' ? '' : widget.profile.nip,
    );

    final existingRayon = widget.profile.rayon.trim();
    if (existingRayon.isNotEmpty && existingRayon != '-') {
      _selectedRayon = existingRayon;
      for (final rayon in _rayonOptions) {
        if (rayon['title'] == existingRayon ||
            existingRayon.contains(rayon['code']!) ||
            existingRayon.contains(rayon['title']!.split(' — ')[0])) {
          _selectedRayon = rayon['title'];
          break;
        }
      }
      if (!_rayonOptions.any((option) => option['title'] == _selectedRayon)) {
        _rayonOptions.insert(0, {
          'title': existingRayon,
          'desc': 'Wilayah penugasan saat ini',
        });
      }
    }
    final existingJob = widget.profile.jobTitle.trim();
    if (existingJob.isNotEmpty && existingJob != '-') {
      _selectedJobTitle = existingJob;
      if (!_jobTitleOptions.contains(existingJob)) {
        _jobTitleOptions.insert(0, existingJob);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nipController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_saving || ref.read(authControllerProvider).isLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final updated = widget.profile.copyWith(
      fullName: _nameController.text.trim(),
      nip: _nipController.text.trim(),
      rayon: _selectedRayon!,
      jobTitle: _selectedJobTitle!,
    );
    final success = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? AppColors.primary : const Color(0xFFAD3636),
        behavior: SnackBarBehavior.floating,
        content: Text(
          success
              ? 'Profil berhasil diperbarui.'
              : 'Profil belum tersimpan. Periksa koneksi dan coba lagi.',
        ),
      ),
    );
    if (success) {
      // Let PopScope reflect the completed save before closing this route.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<String?> _pickOption({
    required String title,
    required String? selected,
    required List<Map<String, String>> options,
  }) async {
    FocusScope.of(context).unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup pilihan',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(LucideIcons.x, size: 21),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final active = option['title'] == selected;
                    return Semantics(
                      selected: active,
                      child: Material(
                        color: active ? AppColors.primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              Navigator.pop(sheetContext, option['title']),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option['title']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          height: 1.5,
                                          color: active
                                              ? AppColors.primaryDark
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (option['desc'] != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          option['desc']!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.5,
                                            color: profileSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  active
                                      ? LucideIcons.circleCheck
                                      : LucideIcons.circle,
                                  color: active
                                      ? AppColors.primary
                                      : profileSecondary,
                                  size: 21,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || ref.watch(authControllerProvider).isLoading;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: profileCanvas,
        appBar: AppBar(
          backgroundColor: profileCanvas,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: const Text(
            'Edit profil',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            tooltip: 'Kembali',
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(LucideIcons.chevronLeft),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFDCE6DE))),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: busy ? null : _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.6,
                      ),
                      minimumSize: const Size(0, 54),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Simpan perubahan',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: AbsorbPointer(
                  absorbing: busy,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ProfileAvatar(
                              name: widget.profile.fullName,
                              avatarUrl: widget.profile.avatarUrl,
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: ProfileSectionTitle(
                                title: 'Profil petugas',
                                subtitle:
                                    'Lengkapi identitas dan wilayah penugasan Anda.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        ProfileCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ProfileSectionTitle(
                                title: 'Identitas petugas',
                                subtitle:
                                    'Gunakan data sesuai identitas kedinasan.',
                              ),
                              const SizedBox(height: 22),
                              _label('Nama lengkap'),
                              TextFormField(
                                controller: _nameController,
                                enabled: !busy,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.name],
                                autovalidateMode: AutovalidateMode.onUnfocus,
                                decoration: profileInputDecoration(
                                  'Nama lengkap Anda',
                                  LucideIcons.user,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Nama lengkap wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              _label('Nomor Induk Pegawai'),
                              TextFormField(
                                controller: _nipController,
                                enabled: !busy,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autovalidateMode: AutovalidateMode.onUnfocus,
                                decoration: profileInputDecoration(
                                  'Nomor induk pegawai Anda',
                                  LucideIcons.badgeCheck,
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'NIP wajib diisi'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              _label('Jabatan'),
                              _selectionField(
                                value: _selectedJobTitle,
                                title: 'Pilih jabatan',
                                icon: LucideIcons.briefcase,
                                options: _jobTitleOptions
                                    .map((job) => {'title': job})
                                    .toList(),
                                onChanged: (value) => _selectedJobTitle = value,
                              ),
                              const SizedBox(height: 18),
                              _label('Wilayah penugasan'),
                              _selectionField(
                                value: _selectedRayon,
                                title: 'Pilih rayon',
                                icon: LucideIcons.mapPin,
                                options: _rayonOptions,
                                onChanged: (value) => _selectedRayon = value,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        ProfileCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ProfileSectionTitle(
                                title: 'Akun & instansi',
                                subtitle: 'Informasi akun terdaftar.',
                              ),
                              ProfileDetail(
                                icon: LucideIcons.building,
                                label: 'Instansi',
                                value: widget.profile.instansi,
                              ),
                              const Divider(height: 1, color: AppColors.border),
                              ProfileDetail(
                                icon: LucideIcons.mail,
                                label: 'Email',
                                value: widget.profile.email,
                                last: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
  );

  Widget _selectionField({
    required String? value,
    required String title,
    required IconData icon,
    required List<Map<String, String>> options,
    required ValueChanged<String> onChanged,
  }) => FormField<String>(
    initialValue: value,
    validator: (value) => value == null || value.trim().isEmpty
        ? 'Silakan ${title.toLowerCase()}.'
        : null,
    builder: (field) => Semantics(
      button: true,
      label: title,
      value: field.value,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final selection = await _pickOption(
              title: title,
              selected: field.value,
              options: options,
            );
            if (!mounted || !field.mounted || selection == null) return;
            field.didChange(selection);
            onChanged(selection);
          },
          child: InputDecorator(
            decoration: profileInputDecoration(
              title,
              icon,
            ).copyWith(errorText: field.errorText),
            isEmpty: field.value == null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    field.value ?? title,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: field.value == null
                          ? profileSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: profileSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
