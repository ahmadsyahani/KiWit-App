import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_form_layout.dart';

/// Wraps the app navigator so a recovery link also replaces a currently open
/// login/forgot-password route. Tokens are handled by Supabase's PKCE client.
class AuthRecoveryGuard extends ConsumerWidget {
  const AuthRecoveryGuard({
    super.key,
    required this.child,
    this.appNavigatorKey,
  });
  final Widget child;
  final GlobalKey<NavigatorState>? appNavigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          appNavigatorKey?.currentState?.popUntil((route) => route.isFirst);
        });
      } else if (event == AuthChangeEvent.signedOut) {
        ref.read(passwordRecoveryPendingProvider.notifier).state = false;
      }
    });
    final recovering = ref.watch(passwordRecoveryPendingProvider);
    // Retain the navigator while blocking both touch and accessibility access.
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: recovering,
          child: ExcludeFocus(
            excluding: recovering,
            child: IgnorePointer(ignoring: recovering, child: child),
          ),
        ),
        if (recovering)
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const ResetPasswordScreen(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _saved = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (ref.read(authControllerProvider).isLoading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    final success = await ref
        .read(authControllerProvider.notifier)
        .updatePassword(_password.text);
    if (!mounted) return;
    setState(() {
      _saved = success;
      if (!success) {
        _error =
            'Kata sandi belum tersimpan. Periksa koneksi dan coba lagi. Jika tautan kedaluwarsa, minta tautan baru.';
      }
    });
    if (success) {
      _password.clear();
      _confirmation.clear();
    }
  }

  Future<void> _finishRecovery() async {
    if (ref.read(authControllerProvider).isLoading) return;
    setState(() => _error = null);
    final success = await ref.read(authControllerProvider.notifier).signOut();
    // The signedOut event may already have dismissed this screen.
    if (!mounted) return;
    if (success) {
      ref.read(passwordRecoveryPendingProvider.notifier).state = false;
    } else {
      setState(
        () => _error =
            'Kata sandi sudah diperbarui, tetapi sesi belum berhasil diakhiri. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return AuthFormLayout(
      title: _saved ? 'Kata sandi\ndiperbarui.' : 'Buat kata\nsandi baru.',
      subtitle: _saved
          ? 'Silakan masuk kembali menggunakan kata sandi baru Anda.'
          : 'Gunakan kata sandi yang kuat untuk akun KiWit Anda.',
      formTitle: _saved ? 'Pemulihan berhasil' : 'Atur ulang kata sandi',
      child: _saved
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Kata sandi berhasil disimpan. Tekan tombol di bawah untuk mengakhiri sesi pemulihan dan kembali ke halaman masuk.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: busy ? null : _finishRecovery,
                  child: Text(busy ? 'Mengakhiri sesi…' : 'Oke, masuk kembali'),
                ),
              ],
            )
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthField(
                    label: 'Kata sandi baru',
                    child: TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        hintText: 'Minimal 8 karakter',
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Tampilkan kata sandi'
                              : 'Sembunyikan kata sandi',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? 'Gunakan minimal 8 karakter.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AuthField(
                    label: 'Ulangi kata sandi',
                    child: TextFormField(
                      controller: _confirmation,
                      enabled: !busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      validator: (value) =>
                          value != _password.text || (value?.isEmpty ?? true)
                          ? 'Kata sandi belum sama.'
                          : null,
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    child: Text(busy ? 'Menyimpan…' : 'Simpan kata sandi'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            // Signing out clears the recovery session before returning to login.
                            final success = await ref
                                .read(authControllerProvider.notifier)
                                .signOut();
                            if (!mounted) return;
                            if (success) {
                              ref
                                      .read(
                                        passwordRecoveryPendingProvider
                                            .notifier,
                                      )
                                      .state =
                                  false;
                            } else {
                              setState(
                                () => _error =
                                    'Belum dapat keluar dari pemulihan. Coba lagi.',
                              );
                            }
                          },
                    child: const Text('Batalkan pemulihan'),
                  ),
                ],
              ),
            ),
    );
  }
}
