import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class AuthRepository {
  static const passwordRecoveryRedirect = 'kiwit://auth/recovery';
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;
  Session? get currentSession => _supabase.auth.currentSession;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign In with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Gagal melakukan login: ${e.toString()}');
    }
  }

  /// Sign Up with Email, Password, & Officer Profile Metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String nip,
    String rayon = 'Rayon 3 — Sukolilo',
    String instansi = 'DLH Kota Surabaya',
    String jobTitle = 'Petugas Lapangan DLH Surabaya',
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'nip': nip.trim(),
          'rayon': rayon.trim(),
          'instansi': instansi.trim(),
          'job_title': jobTitle.trim(),
          'inspected_trees_count': 0,
          'reports_count': 0,
        },
      );

      // Attempt to upsert into 'profiles' table if it exists
      if (response.user != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': response.user!.id,
            'email': email.trim(),
            'full_name': fullName.trim(),
            'nip': nip.trim(),
            'rayon': rayon.trim(),
            'instansi': instansi.trim(),
            'job_title': jobTitle.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (dbError) {
          if (kDebugMode) {
            debugPrint(
              '[AuthRepository] Notice: profiles table sync skipped ($dbError). Data preserved in user_metadata.',
            );
          }
        }
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Gagal mendaftar akun: ${e.toString()}');
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Gagal logout: ${e.toString()}');
    }
  }

  /// Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: passwordRecoveryRedirect,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Gagal mengirim link reset password: ${e.toString()}');
    }
  }

  /// Fetch User Profile (from DB profiles table or Auth User Metadata)
  Future<UserProfile?> fetchUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    Map<String, dynamic> stored = {};
    try {
      // 1. First try fetching from 'profiles' table
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        stored = data;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[AuthRepository] Profiles table lookup failed, using metadata: $e',
        );
      }
    }

    // Auth metadata is the canonical source for editable fields. A failed
    // optional profiles-table mirror must not bring back older field values.
    final metadata = user.userMetadata ?? {};
    return UserProfile.fromJson({
      'full_name': user.email?.split('@').first ?? 'Petugas DLH',
      ...stored,
      ...metadata,
      'id': user.id,
      'email': user.email ?? '',
    });
  }

  Future<void> updatePassword(String password) async {
    if (currentSession == null) {
      throw const AuthException(
        'Tautan pemulihan tidak berlaku. Minta tautan baru.',
      );
    }
    await _supabase.auth.updateUser(UserAttributes(password: password));
  }

  /// Update User Profile
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    final user = currentUser;
    if (user == null) throw Exception('Pengguna belum login.');

    // 1. Update Auth metadata
    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'full_name': profile.fullName,
          'job_title': profile.jobTitle,
          'nip': profile.nip,
          'rayon': profile.rayon,
          'instansi': profile.instansi,
        },
      ),
    );

    // 2. Update DB profile table if available
    try {
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': profile.email,
        'full_name': profile.fullName,
        'job_title': profile.jobTitle,
        'nip': profile.nip,
        'rayon': profile.rayon,
        'instansi': profile.instansi,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthRepository] DB profiles update skipped: $e');
      }
    }

    return profile;
  }
}
