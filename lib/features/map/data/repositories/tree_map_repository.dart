import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/domain/models/inspection_location.dart';
import '../models/tree_map_model.dart';

class MapInspectionData {
  MapInspectionData({
    required List<TreeMapModel> markers,
    required List<SavedInspection> withoutLocation,
    required this.totalCount,
  }) : markers = List.unmodifiable(markers),
       withoutLocation = List.unmodifiable(withoutLocation);

  final List<TreeMapModel> markers;
  final List<SavedInspection> withoutLocation;
  final int totalCount;
  int get matchingCount => markers.length + withoutLocation.length;
}

/// Projects the existing local/cloud inspection feed onto the map.
/// There is no second database query, invented coordinate, or demo fallback.
class TreeMapRepository {
  const TreeMapRepository();

  MapInspectionData project(
    List<SavedInspection> records, {
    String rayon = 'Semua Rayon',
    RiskLevel? risk,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    final matches = records.where((record) {
      if (rayon != 'Semua Rayon' && rayonKey(record.rayon) != rayonKey(rayon)) {
        return false;
      }
      if (risk != null && record.riskLevel != risk) return false;
      return needle.isEmpty || [
        record.data.inspectionId,
        record.data.treeSpecies,
        record.data.locationAddress,
      ].any((value) => value.toLowerCase().contains(needle));
    }).toList()
      ..sort((a, b) {
        final date = b.data.scanTimestamp.compareTo(a.data.scanTimestamp);
        return date != 0 ? date : a.id.compareTo(b.id);
      });

    final markers = <TreeMapModel>[];
    final withoutLocation = <SavedInspection>[];
    for (final record in matches) {
      if (validInspectionCoordinates(
        record.data.latitude, record.data.longitude,
      )) {
        markers.add(TreeMapModel(record));
      } else {
        withoutLocation.add(record);
      }
    }
    return MapInspectionData(
      markers: markers,
      withoutLocation: withoutLocation,
      totalCount: records.length,
    );
  }
}

String rayonKey(String value) {
  final normalized = value.trim().toLowerCase();
  final number = RegExp(r'\brayon\s*(\d+)\b').firstMatch(normalized);
  return number == null
      ? normalized.replaceAll(RegExp(r'\s+'), ' ')
      : 'rayon:${int.parse(number.group(1)!)}';
}

List<String> inspectionRayonOptions(List<SavedInspection> records) {
  final labels = <String, String>{};
  for (final record in records) {
    final key = rayonKey(record.rayon);
    labels[key] = key.startsWith('rayon:')
        ? 'Rayon ${key.substring(6)}'
        : record.rayon.trim();
  }
  final entries = labels.entries.toList()..sort((a, b) {
    final aNumber = int.tryParse(a.key.replaceFirst('rayon:', ''));
    final bNumber = int.tryParse(b.key.replaceFirst('rayon:', ''));
    if (aNumber != null && bNumber != null) return aNumber.compareTo(bNumber);
    return a.value.compareTo(b.value);
  });
  return entries.map((entry) => entry.value).toList();
}
