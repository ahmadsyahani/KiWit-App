import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/presentation/providers/inspection_providers.dart';
import '../../data/models/tree_map_model.dart';
import '../../data/repositories/tree_map_repository.dart';

enum MapLayerType {
  voyager(
    name: 'Standar',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  ),
  satellite(
    name: 'Satelit',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  terrain(
    name: 'Topografi',
    urlTemplate: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
  );

  const MapLayerType({required this.name, required this.urlTemplate});

  final String name;
  final String urlTemplate;
}

final selectedMapLayerProvider = StateProvider<MapLayerType>((ref) => MapLayerType.voyager);
final highlightHighRiskProvider = StateProvider<bool>((ref) => true);
final showTreeMarkersProvider = StateProvider<bool>((ref) => true);

final selectedRayonFilterProvider = StateProvider<String>((ref) {
  ref.watch(currentUserIdProvider);
  return 'Semua Rayon';
});
final selectedRiskFilterProvider = StateProvider<RiskLevel?>((ref) {
  ref.watch(currentUserIdProvider);
  return null;
});
final mapSearchQueryProvider = StateProvider<String>((ref) {
  ref.watch(currentUserIdProvider);
  return '';
});

final mapInspectionDataProvider = Provider<AsyncValue<MapInspectionData>>((ref) {
  final feed = ref.watch(inspectionControllerProvider);
  final rayon = ref.watch(selectedRayonFilterProvider);
  final risk = ref.watch(selectedRiskFilterProvider);
  final query = ref.watch(mapSearchQueryProvider);
  return feed.whenData((value) => const TreeMapRepository().project(
    value.records, rayon: rayon, risk: risk, query: query,
  ));
});

final mapTreesListProvider = Provider<AsyncValue<List<TreeMapModel>>>((ref) =>
    ref.watch(mapInspectionDataProvider).whenData((data) => data.markers));

final selectedTreeMapIdProvider = StateProvider<String?>((ref) {
  ref.watch(currentUserIdProvider);
  ref.watch(selectedRayonFilterProvider);
  ref.watch(selectedRiskFilterProvider);
  ref.watch(mapSearchQueryProvider);
  return null;
});

final selectedTreeMapItemProvider = Provider<TreeMapModel?>((ref) {
  final id = ref.watch(selectedTreeMapIdProvider);
  final markers = ref.watch(mapTreesListProvider).valueOrNull;
  for (final marker in markers ?? <TreeMapModel>[]) {
    if (marker.id == id) return marker;
  }
  return null;
});

final mapRayonOptionsProvider = Provider<List<String>>((ref) {
  final records = ref.watch(inspectionControllerProvider).valueOrNull?.records;
  return inspectionRayonOptions(records ?? []);
});
