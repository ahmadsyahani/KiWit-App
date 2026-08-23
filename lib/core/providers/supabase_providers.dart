import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Provider exposing the [SupabaseClient] instance for dependency injection across features.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

/// Provider exposing the [GoTrueClient] auth instance.
final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth;
});

/// Stream provider for listening to authentication state changes in real time.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final auth = ref.watch(supabaseAuthProvider);
  return auth.onAuthStateChange;
});

/// Reactive provider returning the currently logged in [User], or null if unauthenticated.
final currentUserProvider = Provider<User?>((ref) {
  // Watch stream so any login / logout triggers automatic re-evaluation
  ref.watch(authStateChangesProvider);
  final auth = ref.watch(supabaseAuthProvider);
  return auth.currentUser;
});

/// Reactive provider returning the current user ID, or null.
final currentUserIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id;
});

/// Reactive provider checking whether a user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
