import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

/// Professional service wrapper for Supabase client lifecycle and error handling.
class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;

  /// Returns true if Supabase has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Get the global Supabase client instance.
  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'SupabaseService has not been initialized. Call SupabaseService.initialize() before accessing client.',
      );
    }
    return Supabase.instance.client;
  }

  /// Get the Supabase Auth instance.
  static GoTrueClient get auth => client.auth;

  /// Initialize Supabase with proper error handling and logging.
  static Future<void> initialize() async {
    if (_isInitialized) return;

    final url = EnvConfig.supabaseUrl;
    final anonKey = EnvConfig.supabaseAnonKey;

    if (!EnvConfig.isConfigured && kDebugMode) {
      debugPrint('⚠️ [SupabaseService] Notice: Supabase credentials are using placeholder values.');
      debugPrint('⚠️ [SupabaseService] Please update your .env file with your actual Supabase URL & Anon Key.');
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: kDebugMode,
      );

      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('✅ [SupabaseService] Supabase successfully initialized.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseService] Failed to initialize Supabase: $e');
        debugPrint(stackTrace.toString());
      }
      // Re-throw or handle gracefully depending on app requirements
      // For development robustness, we keep _isInitialized false
    }
  }
}
