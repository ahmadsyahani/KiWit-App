import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_form_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (ref.read(authControllerProvider).isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    final success = await ref.read(authControllerProvider.notifier).resetPassword(
          _emailController.text.trim(),
        );

    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(LucideIcons.mailCheck, color: AppColors.primary, size: 28),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Email terkirim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: Text(
              'Tautan pemulihan kata sandi telah dikirimkan ke ${_emailController.text.trim()}. Silakan periksa kotak masuk atau folder spam Anda.',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        );
      } else {
        final authState = ref.read(authControllerProvider);
        final errorMessage = authState.error?.toString().replaceAll('Exception: ', '') ??
            'Gagal mengirim tautan reset password. Periksa kembali email Anda.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(errorMessage),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthFormLayout(
      title: 'Pulihkan akses',
      subtitle: 'Kami akan mengirim tautan pemulihan ke email yang terdaftar.',
      onBack: () => Navigator.pop(context),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email terdaftar',
                child: TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  onFieldSubmitted: (_) => _handleReset(),
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
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Kirim tautan pemulihan',
                loadingLabel: 'Mengirim tautan...',
                isLoading: isLoading,
                onPressed: _handleReset,
              ),
              const SizedBox(height: 18),
              AuthNavigationPrompt(
                prompt: 'Ingat kata sandi?',
                actionLabel: 'Kembali masuk',
                onPressed: isLoading ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
