import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../main_wrapper/main_navigation_screen.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';

/// An authentication gate widget that dynamically switches between
/// [MainNavigationScreen] (when user is authenticated or guest) and [LoginScreen].
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStateAsync = ref.watch(authStateProvider);

    return authStateAsync.when(
      data: (authState) {
        if (authState.session != null) {
          return const MainNavigationScreen();
        }
        return const LoginScreen();
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (error, stackTrace) => const MainNavigationScreen(),

    );
  }
}
