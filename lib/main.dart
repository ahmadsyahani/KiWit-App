import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/main_wrapper/main_navigation_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
