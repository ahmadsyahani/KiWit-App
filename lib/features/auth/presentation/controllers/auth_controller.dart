import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

/// Provider for AuthRepository, safe if Supabase is uninitialized
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  if (supabase == null) return null;
  return AuthRepository(supabase);
});

/// Stream provider that watches the auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return const Stream.empty();
  return repository.authStateChanges;
});

// Keep recovery active across token refresh / userUpdated events until the
// password form has finished. A recovery session must not open the dashboard.
final passwordRecoveryPendingProvider = StateProvider<bool>((ref) => false);

/// Reactive Provider for fetching and caching current user's profile from Supabase Database
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // Watch user and auth state changes so profile updates immediately on login/logout
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repository = ref.read(authRepositoryProvider);
  if (repository == null) return null;
  return await repository.fetchUserProfile();
});

/// Controller for auth actions (login, register, logout, update profile)
final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AuthController(this._ref) : super(const AsyncValue.data(null));

  AuthRepository? get _authRepository => _ref.read(authRepositoryProvider);

  Future<AuthRepository?> _readyRepository() async {
    if (_authRepository != null) return _authRepository;
    try {
      await SupabaseService.initialize().timeout(const Duration(seconds: 10));
    } catch (_) {
      // A late completion still updates supabaseClientProvider through readiness.
    }
    return _authRepository;
  }

  /// Sign In with Email & Password
  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    final repo = await _readyRepository();
    if (repo == null) {
      state = AsyncValue.error(
        Exception('Koneksi Supabase belum siap atau sedang offline.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      await repo.signIn(email: email, password: password);
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Sign Up new user
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String nip,
    String rayon = 'Rayon 3 — Sukolilo',
    String instansi = 'DLH Kota Surabaya',
    String jobTitle = 'Petugas Lapangan DLH Surabaya',
  }) async {
    state = const AsyncValue.loading();
    final repo = await _readyRepository();
    if (repo == null) {
      state = AsyncValue.error(
        Exception('Koneksi Supabase belum siap atau sedang offline.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      await repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        nip: nip,
        rayon: rayon,
        instansi: instansi,
        jobTitle: jobTitle,
      );
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Sign Out
  Future<bool> signOut() async {
    final repo = _authRepository;
    if (repo == null) return true;

    state = const AsyncValue.loading();
    try {
      await repo.signOut();
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Send Reset Password link
  Future<bool> resetPassword(String email) async {
    state = const AsyncValue.loading();
    final repo = await _readyRepository();
    if (repo == null) {
      state = AsyncValue.error(
        Exception('Koneksi Supabase belum siap atau sedang offline.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      await repo.sendPasswordResetEmail(email);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Update Profile Data
  Future<bool> updatePassword(String password) async {
    final repo = _authRepository;
    state = const AsyncValue.loading();
    try {
      if (repo == null) throw const AuthException('Koneksi akun belum siap.');
      await repo.updatePassword(password);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    final repo = _authRepository;
    if (repo == null) return false;

    state = const AsyncValue.loading();
    try {
      await repo.updateUserProfile(profile);
      _ref.invalidate(userProfileProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
