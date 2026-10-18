import '../../../../core/widgets/risk_badge.dart';
import '../../../scan/data/models/saved_inspection.dart';
import '../../../scan/domain/models/inspection_location.dart';

/// One marker represents one saved inspection, identified by its stable UUID.
/// Inspections are not merged by their display code or estimated coordinates.
class TreeMapModel {
  TreeMapModel(this.record) {
    if (!validInspectionCoordinates(
      record.data.latitude, record.data.longitude,
    )) {
      throw ArgumentError('Inspeksi tidak memiliki koordinat yang valid.');
    }
  }

  final SavedInspection record;

  String get id => record.id;
  String get treeCode => record.data.inspectionId;
  String get speciesName => record.data.treeSpecies;
  double get latitude => record.data.latitude!;
  double get longitude => record.data.longitude!;
  String get address => record.data.locationAddress;
  String get rayon => record.rayon;
  RiskLevel get riskLevel => record.riskLevel;
  bool get isSynced => record.isSynced;
}
