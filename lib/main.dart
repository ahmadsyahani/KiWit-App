import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/main_wrapper/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables & initialize Supabase
  await EnvConfig.initialize();
  await SupabaseService.initialize();

  runApp(const ProviderScope(child: KiWitApp()));
}


class KiWitApp extends StatelessWidget {
  const KiWitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiWit AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
    );
  }
}
