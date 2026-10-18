import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_layout.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (ref.read(authControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await ref
        .read(authControllerProvider.notifier)
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primary,
            content: Text('Berhasil masuk ke akun Petugas DLH!'),
          ),
        );
        // If opened as modal/route, pop back; if root, state changes will handle navigation
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      } else {
        final authState = ref.read(authControllerProvider);
        final err = authState.error;
        String errorMessage =
            'Login gagal. Periksa kembali email dan kata sandi Anda.';

        if (err != null) {
          final errStr = err.toString().toLowerCase();
          if (errStr.contains('invalid login credentials') ||
              errStr.contains('invalid_credentials')) {
            errorMessage =
                'Email atau kata sandi salah. Jika belum punya akun, silakan klik "Daftar Petugas".';
          } else if (errStr.contains('email not confirmed')) {
            errorMessage =
                'Email belum diverifikasi. Silakan periksa inbox email Anda.';
          } else if (errStr.contains('user not found')) {
            errorMessage =
                'Akun belum terdaftar. Silakan daftar terlebih dahulu.';
          } else if (errStr.contains('socketfailed') ||
              errStr.contains('host lookup') ||
              errStr.contains('clientexception') ||
              errStr.contains('authretryablefetchexception')) {
            errorMessage =
                'Tidak dapat terhubung. Periksa koneksi internet, lalu coba lagi.';
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
      title: 'Selamat datang\nkembali.',
      subtitle: 'Rawat pohon kota, mulai dari inspeksi Anda.',
      formTitle: 'Masuk ke akun',
      formSubtitle: 'Lanjutkan catatan dan pantau kondisi pohon.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email',
                child: TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  autocorrect: false,
                  decoration: authInputDecoration(
                    hint: 'nama@contoh.id',
                    icon: LucideIcons.mail,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Masukkan email yang terdaftar.';
                    }
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
                      return 'Periksa kembali format email.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              AuthField(
                label: 'Kata sandi',
                child: TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) => _handleLogin(),
                  decoration: authInputDecoration(
                    hint: 'Masukkan kata sandi',
                    icon: LucideIcons.lock,
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
                      return 'Masukkan kata sandi.';
                    }
                    if (value.length < 6) {
                      return 'Kata sandi minimal 6 karakter.';
                    }
                    return null;
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  ),
                  child: const Text('Lupa kata sandi?'),
                ),
              ),
              const SizedBox(height: 8),
              AuthPrimaryButton(
                label: 'Masuk',
                loadingLabel: 'Sedang masuk...',
                isLoading: isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 18),
              AuthNavigationPrompt(
                prompt: 'Belum punya akun?',
                actionLabel: 'Daftar petugas',
                onPressed: isLoading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
