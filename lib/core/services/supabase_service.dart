import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

/// Professional service wrapper for Supabase client lifecycle and error handling.
class SupabaseService {
  SupabaseService._();

  static bool _isInitialized = false;
  static final readiness = ValueNotifier<bool>(false);
  static Future<void>? _initializing;

  /// Returns true if Supabase has been initialized.
  static bool get isInitialized => _isInitialized;

  /// Get the global Supabase client instance safely, or null if uninitialized.
  static SupabaseClient? get clientOrNull {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Get the global Supabase client instance. Throws StateError if not initialized.
  static SupabaseClient get client {
    final c = clientOrNull;
    if (c == null) {
      throw StateError(
        'SupabaseService has not been initialized. Call SupabaseService.initialize() before accessing client.',
      );
    }
    return c;
  }

  /// Get the Supabase Auth instance safely, or null if uninitialized.
  static GoTrueClient? get authOrNull => clientOrNull?.auth;

  /// Get the Supabase Auth instance.
  static GoTrueClient get auth => client.auth;

  /// Initialize Supabase with proper error handling and logging.
  static Future<void> initialize() {
    if (_isInitialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  static Future<void> _initialize() async {
    final url = EnvConfig.supabaseUrl;
    final anonKey = EnvConfig.supabaseAnonKey;

    if (!EnvConfig.isConfigured && kDebugMode) {
      debugPrint(
        '⚠️ [SupabaseService] Notice: Supabase credentials are using placeholder values.',
      );
      debugPrint(
        '⚠️ [SupabaseService] Please update your .env file with your actual Supabase URL & Anon Key.',
      );
    }

    try {
      await Supabase.initialize(
        url: url,
        publishableKey: anonKey,
        debug: kDebugMode,
      );

      _isInitialized = true;
      readiness.value = true;
      if (kDebugMode) {
        debugPrint('✅ [SupabaseService] Supabase successfully initialized.');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [SupabaseService] Failed to initialize Supabase: $e');
        debugPrint(stackTrace.toString());
      }
      _isInitialized = false;
      readiness.value = false;
    }
  }
}
