import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/env_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher Error] $error');
    return true; 
  };

  try {
    await EnvConfig.initialize().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[EnvConfig] Warning init: $e');
  }

  try {
    await SupabaseService.initialize().timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('[SupabaseService] Warning init: $e');
  }

  runApp(const ProviderScope(child: KiWitApp()));
}

class KiWitApp extends StatelessWidget {
  const KiWitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiWit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      builder: (context, child) {
        // Fallback ErrorWidget kustom: mencegah layar hitam jika ada widget build error
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Terjadi Kendala Tampilan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
