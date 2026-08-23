import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/tree_map_model.dart';
import '../../data/repositories/tree_map_repository.dart';

final treeMapRepositoryProvider = Provider<TreeMapRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TreeMapRepository(supabase);
});

/// Rayon Filter Provider (Defaults to logged in user's Rayon or 'Rayon 3 — Sukolilo')
final selectedRayonFilterProvider = StateProvider<String>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.rayon ?? 'Rayon 3 — Sukolilo';
});

/// Risk Filter Provider (null means 'Semua')
final selectedRiskFilterProvider = StateProvider<RiskLevel?>((ref) => null);

/// Search Query Provider
final mapSearchQueryProvider = StateProvider<String>((ref) => '');

/// Currently Selected Tree Marker on the map (for Bottom Card)
final selectedTreeMapItemProvider = StateProvider<TreeMapModel?>((ref) => null);

/// Is Ping / Add Report Mode Active?
final isMapPingModeProvider = StateProvider<bool>((ref) => false);

/// Filtered Trees Provider for the map
final mapTreesListProvider = FutureProvider<List<TreeMapModel>>((ref) async {
  final repository = ref.watch(treeMapRepositoryProvider);
  final rayon = ref.watch(selectedRayonFilterProvider);
  final risk = ref.watch(selectedRiskFilterProvider);
  final search = ref.watch(mapSearchQueryProvider).toLowerCase().trim();

  final allTrees = await repository.fetchTrees(rayonFilter: rayon);

  return allTrees.where((tree) {
    // 1. Risk Filter
    if (risk != null && tree.riskLevel != risk) {
      return false;
    }

    // 2. Search Filter (by treeCode, species, or address)
    if (search.isNotEmpty) {
      final matchCode = tree.treeCode.toLowerCase().contains(search);
      final matchSpecies = tree.speciesName.toLowerCase().contains(search);
      final matchAddress = tree.address.toLowerCase().contains(search);
      if (!matchCode && !matchSpecies && !matchAddress) {
        return false;
      }
    }

    return true;
  }).toList();
});
