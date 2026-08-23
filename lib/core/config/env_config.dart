import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration management.
///
/// Supports prioritized resolution:
/// 1. `--dart-define` compile-time flags (ideal for CI/CD & production builds)
/// 2. `.env` file via `flutter_dotenv` (ideal for local development)
/// 3. Default fallback values
class EnvConfig {
  EnvConfig._();

  static const String _defaultSupabaseUrl = 'https://placeholder-project.supabase.co';
  static const String _defaultSupabaseAnonKey = 'placeholder-anon-key';

  /// Initialize environment configuration
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
      if (kDebugMode) {
        debugPrint('[EnvConfig] Successfully loaded .env file');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EnvConfig] Warning: .env file could not be loaded ($e). Falling back to system/dart-define envs.');
      }
    }
  }

  /// Supabase Project URL
  static String get supabaseUrl {
    const dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
    if (dartDefineUrl.isNotEmpty) return dartDefineUrl;

    final envUrl = dotenv.maybeGet('SUPABASE_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;

    return _defaultSupabaseUrl;
  }

  /// Supabase Anonymous Public API Key
  static String get supabaseAnonKey {
    const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (dartDefineKey.isNotEmpty) return dartDefineKey;

    final envKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
    if (envKey != null && envKey.isNotEmpty) return envKey;

    return _defaultSupabaseAnonKey;
  }

  /// Checks if Supabase credentials have been configured with valid values
  static bool get isConfigured {
    return supabaseUrl != _defaultSupabaseUrl &&
        supabaseAnonKey != _defaultSupabaseAnonKey &&
        supabaseUrl.startsWith('https://');
  }
}
