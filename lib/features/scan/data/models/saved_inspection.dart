import '../../../../core/widgets/risk_badge.dart';
import '../../domain/models/inspection_result_data.dart';

class SavedInspection {
  const SavedInspection({
    required this.id,
    required this.ownerId,
    required this.data,
    required this.savedAt,
    required this.notes,
    required this.inspectorName,
    required this.rayon,
    this.photoStoragePath,
    this.isSynced = false,
  });

  final String id;
  final String ownerId;
  final InspectionResultData data;
  final DateTime savedAt;
  final String notes;
  final String inspectorName;
  final String rayon;
  final String? photoStoragePath;
  final bool isSynced;

  RiskLevel get riskLevel {
    switch (data.riskStatus.toLowerCase()) {
      case 'kritis':
      case 'ekstrem':
      case 'extreme':
      case 'critical':
        return RiskLevel.kritis;
      case 'tinggi':
      case 'high':
        return RiskLevel.tinggi;
      case 'sedang':
      case 'medium':
        return RiskLevel.sedang;
      default:
        return RiskLevel.rendah;
    }
  }

  SavedInspection copyWith({
    InspectionResultData? data,
    String? photoStoragePath,
    bool? isSynced,
  }) => SavedInspection(
    id: id,
    ownerId: ownerId,
    data: data ?? this.data,
    savedAt: savedAt,
    notes: notes,
    inspectorName: inspectorName,
    rayon: rayon,
    photoStoragePath: photoStoragePath ?? this.photoStoragePath,
    isSynced: isSynced ?? this.isSynced,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'data': data.toJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
    'notes': notes,
    'inspectorName': inspectorName,
    'rayon': rayon,
    'photoStoragePath': photoStoragePath,
    'isSynced': isSynced,
  };

  factory SavedInspection.fromJson(Map<String, dynamic> json) {
    return SavedInspection(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      data: InspectionResultData.fromJson(
        Map<String, dynamic>.from(json['data'] as Map),
      ),
      savedAt: DateTime.parse(json['savedAt'] as String).toLocal(),
      notes: json['notes'] as String? ?? '',
      inspectorName: json['inspectorName'] as String? ?? '',
      rayon: json['rayon'] as String? ?? '',
      photoStoragePath: json['photoStoragePath'] as String?,
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }
}

String formatInspectionDate(DateTime value) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final local = value.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

/// Construct calendar dates instead of subtracting 24-hour intervals.
List<DateTime> inspectionWeekDays(DateTime now) {
  final local = now.toLocal();
  return List.generate(
    7,
    (index) => DateTime(local.year, local.month, local.day - 6 + index),
  );
}

List<int> inspectionDailyCounts(List<SavedInspection> records, DateTime now) {
  final days = inspectionWeekDays(now);
  final counts = List<int>.filled(7, 0);
  for (final record in records) {
    final date = record.data.scanTimestamp.toLocal();
    for (var index = 0; index < days.length; index++) {
      final day = days[index];
      if (date.year == day.year && date.month == day.month && date.day == day.day) {
        counts[index]++;
        break;
      }
    }
  }
  return counts;
}
