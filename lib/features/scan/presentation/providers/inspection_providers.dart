import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/repositories/inspection_controller.dart';
import '../../data/repositories/inspection_local_storage.dart';
import '../../data/repositories/supabase_inspection_remote.dart';

final inspectionControllerProvider = StateNotifierProvider<
    InspectionController, AsyncValue<InspectionFeed>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final client = ref.watch(supabaseClientProvider);
  final ownerId = userId ?? 'guest';
  return InspectionController(
    ownerId: ownerId,
    local: FileInspectionStorage(ownerId),
    remote: client != null && userId != null
        ? SupabaseInspectionRemote(client, userId)
        : null,
  );
});

final inspectionPhotoUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, path) async {
  final remote = ref.watch(inspectionControllerProvider.notifier).remote;
  if (remote == null || !remote.canSync) return null;
  final expiry = Timer(const Duration(minutes: 50), ref.invalidateSelf);
  ref.onDispose(expiry.cancel);
  return remote.photoUrl(path);
});
