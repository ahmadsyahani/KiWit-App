import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRayon = 'Rayon 3 — Sukolilo';
  final String _instansi = 'DLH Kota Surabaya';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _rayonOptions = [
    'Rayon 1 — Genteng / Pusat',
    'Rayon 2 — Rungkut / Timur',
    'Rayon 3 — Sukolilo',
    'Rayon 4 — Sawahan / Selatan',
    'Rayon 5 — Tandes / Barat',
    'Rayon 6 — Kenjeran / Utara',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (ref.read(authControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          nip: _nipController.text.trim(),
          rayon: _selectedRayon,
          instansi: _instansi,
          jobTitle: 'Petugas Lapangan $_instansi',
        );

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(
                  LucideIcons.checkCircle,
                  color: AppColors.primary,
                  size: 28,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pendaftaran berhasil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Akun Petugas DLH Anda telah berhasil didaftarkan. Jika konfirmasi email diaktifkan, silakan periksa inbox email Anda.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // close dialog
                  Navigator.pop(context); // return to login
                },
                child: const Text('Ke Halaman Masuk'),
              ),
            ],
          ),
        );
      } else {
        final authState = ref.read(authControllerProvider);
        final err = authState.error;
        String errorMessage = 'Pendaftaran gagal. Silakan coba kembali.';

        if (err != null) {
          final errStr = err.toString().toLowerCase();
          if (errStr.contains('user already registered') ||
              errStr.contains('already exists')) {
            errorMessage =
                'Email sudah terdaftar. Silakan langsung masuk di menu Login.';
          } else if (errStr.contains('password should be at least')) {
            errorMessage = 'Kata sandi minimal 6 karakter.';
          } else {
            errorMessage = err
                .toString()
                .replaceAll('Exception: ', '')
                .replaceAll('AuthApiException', '')
                .replaceAll('AuthException', '');
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMessage)),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthFormLayout(
      title: 'Buat akun\npetugas.',
      subtitle: 'Catat setiap inspeksi, jaga pohon di wilayah Anda.',
      onBack: isLoading ? null : () => Navigator.pop(context),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthSectionTitle(title: 'Identitas petugas',
                subtitle: 'Data diri dan wilayah penugasan Anda.'),
              AuthField(
                label: 'Nama lengkap',
                child: TextFormField(
                  controller: _nameController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: authInputDecoration(
                    hint: 'Nama sesuai identitas',
                    icon: LucideIcons.user,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Masukkan nama lengkap.'
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'NIP / ID petugas',
                child: TextFormField(
                  controller: _nipController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: authInputDecoration(
                    hint: 'Nomor identitas petugas',
                    icon: LucideIcons.badgeCheck,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Masukkan NIP atau ID petugas.'
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Rayon penugasan',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedRayon,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  isExpanded: true,
                  isDense: false,
                  itemHeight: null,
                  menuMaxHeight: 360,
                  borderRadius: BorderRadius.circular(14),
                  decoration: authInputDecoration(
                    hint: 'Pilih rayon',
                    icon: LucideIcons.mapPin,
                  ),
                  selectedItemBuilder: (context) => _rayonOptions.map((rayon) {
                    return Text(rayon, style: const TextStyle(fontSize: 14));
                  }).toList(),
                  items: _rayonOptions.map((rayon) {
                    return DropdownMenuItem<String>(
                      value: rayon,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          rayon,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: isLoading
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedRayon = value);
                          }
                        },
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F6F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.building, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _instansi,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Divider(height: 1, color: Color(0xFFE4EBE5)),
              ),
              const AuthSectionTitle(title: 'Akses akun',
                subtitle: 'Gunakan email aktif untuk masuk dan pemulihan akun.'),
              AuthField(
                label: 'Email aktif',
                child: TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  decoration: authInputDecoration(
                    hint: 'nama@contoh.id',
                    icon: LucideIcons.mail,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan email aktif.';
                    }
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                      return 'Periksa kembali format email.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Kata sandi',
                child: TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: authInputDecoration(
                    hint: 'Buat kata sandi',
                    icon: LucideIcons.lock,
                    helperText: 'Gunakan minimal 6 karakter.',
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: const Color(0xFF5C7064),
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Buat kata sandi untuk akun.';
                    }
                    if (value.length < 6) {
                      return 'Kata sandi minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'Konfirmasi kata sandi',
                child: TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  obscureText: _obscureConfirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) => _handleRegister(),
                  decoration: authInputDecoration(
                    hint: 'Ulangi kata sandi',
                    icon: LucideIcons.lock,
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmPassword ? 'Tampilkan konfirmasi sandi' : 'Sembunyikan konfirmasi sandi',
                      onPressed: isLoading
                          ? null
                          : () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      icon: Icon(
                        _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                        color: const Color(0xFF5C7064),
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ulangi kata sandi.';
                    }
                    if (value != _passwordController.text) {
                      return 'Kata sandi belum sama.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 26),
              AuthPrimaryButton(
                label: 'Buat akun petugas',
                loadingLabel: 'Mendaftarkan akun...',
                isLoading: isLoading,
                onPressed: _handleRegister,
              ),
              const SizedBox(height: 18),
              AuthNavigationPrompt(
                prompt: 'Sudah punya akun?',
                actionLabel: 'Masuk',
                onPressed: isLoading ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
