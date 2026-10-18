import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/supabase_providers.dart';
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
final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<void>>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  AuthController(this._ref) : super(const AsyncValue.data(null));

  AuthRepository? get _authRepository => _ref.read(authRepositoryProvider);

  /// Sign In with Email & Password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final repo = _authRepository;
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
    final repo = _authRepository;
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
    final repo = _authRepository;
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
