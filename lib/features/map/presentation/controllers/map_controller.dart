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

enum MapLayerType {
  voyager(
    name: 'Carto Voyager',
    subtitle: 'Peta modern, jernih & bersih (Rekomendasi)',
    urlTemplate: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    tag: 'Rekomendasi',
  ),
  satellite(
    name: 'Citra Satelit',
    subtitle: 'Foto udara satelit resolusi tinggi',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    tag: 'Realistis',
  ),
  osm(
    name: 'OpenStreetMap',
    subtitle: 'Peta jalan standar komunitas OSM',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    tag: 'Klasik',
  ),
  positron(
    name: 'Minimalis Light',
    subtitle: 'Tampilan kontras tinggi abu-abu bersih',
    urlTemplate: 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
    tag: 'Clean',
  ),
  dark(
    name: 'Dark Mode (Malam)',
    subtitle: 'Tema gelap elegan untuk malam hari',
    urlTemplate: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    tag: 'Gelap',
  ),
  terrain(
    name: 'Topografi & Kontur',
    subtitle: 'Garis kontur ketinggian dan kontur alam',
    urlTemplate: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    tag: 'Terain',
  );

  final String name;
  final String subtitle;
  final String urlTemplate;
  final String tag;

  const MapLayerType({
    required this.name,
    required this.subtitle,
    required this.urlTemplate,
    required this.tag,
  });
}

/// Selected Map Layer Provider (Default to modern Voyager)
final selectedMapLayerProvider = StateProvider<MapLayerType>((ref) => MapLayerType.voyager);

/// Overlay Toggle Providers
final showDangerZonesProvider = StateProvider<bool>((ref) => true);
final showTreeMarkersProvider = StateProvider<bool>((ref) => true);

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
