class InspectionResultData {
  final bool hasAssessment;
  final bool hasMeasuredDiameter;
  final bool hasMeasuredInclination;
  final bool hasPathologyAssessment;
  final String imagePath;
  final int healthScore;
  final String riskStatus;
  final double ronggaBatang;
  final double sudutKemiringan;
  final double diameter;
  final bool isJamurPelapuk;
  final String inspectionId;
  final String treeSpecies;
  final String detectedCondition;
  final String locationAddress;
  final DateTime scanTimestamp;
  final double? latitude;
  final double? longitude;

  // Photo screening fields. Retained names preserve saved payload compatibility.
  final double persentaseLuka;
  final String
  failurePotential; // 'Improbable', 'Possible', 'Probable', 'Imminent'
  final String environmentalImpact; // 'Low', 'Medium', 'High'
  final String riskAction;
  final bool isOfficerAssessed;
  final String? modelRiskStatus;

  // Display old records without repeating unsupported safety/felling claims.
  String get followUpAction => switch (riskAction) {
    'Aman' => 'Pantau kondisi',
    'Tebang Segera!' => 'Prioritaskan pemeriksaan lapangan',
    _ => riskAction,
  };
  final int healthyPixelCount;
  final int defectPixelCount;

  InspectionResultData({
    this.hasAssessment = true,
    this.hasMeasuredDiameter = false,
    this.hasMeasuredInclination = false,
    this.hasPathologyAssessment = false,
    required this.imagePath,
    required this.healthScore,
    required this.riskStatus,
    required this.ronggaBatang,
    required this.sudutKemiringan,
    required this.diameter,
    required this.isJamurPelapuk,
    required this.inspectionId,
    this.treeSpecies = 'Belum ditentukan',
    required this.detectedCondition,
    required this.locationAddress,
    required this.scanTimestamp,
    this.latitude,
    this.longitude,
    double? persentaseLuka,
    this.failurePotential = 'Improbable',
    this.environmentalImpact = 'Medium',
    this.riskAction = 'Pantau kondisi',
    this.isOfficerAssessed = false,
    this.modelRiskStatus,
    this.healthyPixelCount = 0,
    this.defectPixelCount = 0,
  }) : persentaseLuka = persentaseLuka ?? ronggaBatang;

  factory InspectionResultData.unassessed({
    required String imagePath,
    required String inspectionId,
    required String locationAddress,
    required DateTime scanTimestamp,
    double? latitude,
    double? longitude,
  }) => InspectionResultData(
    hasAssessment: false,
    imagePath: imagePath,
    inspectionId: inspectionId,
    locationAddress: locationAddress,
    scanTimestamp: scanTimestamp,
    latitude: latitude,
    longitude: longitude,
    treeSpecies: 'Belum ditentukan',
    riskStatus: 'Belum dinilai',
    detectedCondition: 'Belum dapat dinilai',
    failurePotential: 'Belum dinilai',
    riskAction: 'Perlu pemeriksaan manual',
    // Storage-compatible placeholders; never displayed as measurements.
    healthScore: 0,
    ronggaBatang: 0,
    sudutKemiringan: 0,
    diameter: 0,
    isJamurPelapuk: false,
  );

  InspectionResultData copyWith({
    bool? hasMeasuredDiameter,
    bool? hasMeasuredInclination,
    bool? hasPathologyAssessment,
    String? imagePath,
    int? healthScore,
    String? riskStatus,
    double? ronggaBatang,
    double? sudutKemiringan,
    double? diameter,
    bool? isJamurPelapuk,
    String? inspectionId,
    String? treeSpecies,
    String? detectedCondition,
    String? locationAddress,
    DateTime? scanTimestamp,
    double? latitude,
    double? longitude,
    double? persentaseLuka,
    String? failurePotential,
    String? environmentalImpact,
    String? riskAction,
    bool? isOfficerAssessed,
    String? modelRiskStatus,
    int? healthyPixelCount,
    int? defectPixelCount,
  }) {
    return InspectionResultData(
      hasAssessment: hasAssessment,
      hasMeasuredDiameter: hasMeasuredDiameter ?? this.hasMeasuredDiameter,
      hasMeasuredInclination:
          hasMeasuredInclination ?? this.hasMeasuredInclination,
      hasPathologyAssessment:
          hasPathologyAssessment ?? this.hasPathologyAssessment,
      imagePath: imagePath ?? this.imagePath,
      healthScore: healthScore ?? this.healthScore,
      riskStatus: riskStatus ?? this.riskStatus,
      ronggaBatang: ronggaBatang ?? this.ronggaBatang,
      sudutKemiringan: sudutKemiringan ?? this.sudutKemiringan,
      diameter: diameter ?? this.diameter,
      isJamurPelapuk: isJamurPelapuk ?? this.isJamurPelapuk,
      inspectionId: inspectionId ?? this.inspectionId,
      treeSpecies: treeSpecies ?? this.treeSpecies,
      detectedCondition: detectedCondition ?? this.detectedCondition,
      locationAddress: locationAddress ?? this.locationAddress,
      scanTimestamp: scanTimestamp ?? this.scanTimestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      persentaseLuka: persentaseLuka ?? this.persentaseLuka,
      failurePotential: failurePotential ?? this.failurePotential,
      environmentalImpact: environmentalImpact ?? this.environmentalImpact,
      riskAction: riskAction ?? this.riskAction,
      isOfficerAssessed: isOfficerAssessed ?? this.isOfficerAssessed,
      modelRiskStatus: modelRiskStatus ?? this.modelRiskStatus,
      healthyPixelCount: healthyPixelCount ?? this.healthyPixelCount,
      defectPixelCount: defectPixelCount ?? this.defectPixelCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'hasAssessment': hasAssessment,
    'hasMeasuredDiameter': hasMeasuredDiameter,
    'hasMeasuredInclination': hasMeasuredInclination,
    'hasPathologyAssessment': hasPathologyAssessment,
    'imagePath': imagePath,
    'healthScore': healthScore,
    'riskStatus': riskStatus,
    'ronggaBatang': ronggaBatang,
    'sudutKemiringan': sudutKemiringan,
    'diameter': diameter,
    'isJamurPelapuk': isJamurPelapuk,
    'inspectionId': inspectionId,
    'treeSpecies': treeSpecies,
    'detectedCondition': detectedCondition,
    'locationAddress': locationAddress,
    'scanTimestamp': scanTimestamp.toUtc().toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'persentaseLuka': persentaseLuka,
    'failurePotential': failurePotential,
    'environmentalImpact': environmentalImpact,
    'riskAction': riskAction,
    'isOfficerAssessed': isOfficerAssessed,
    'modelRiskStatus': modelRiskStatus,
    'healthyPixelCount': healthyPixelCount,
    'defectPixelCount': defectPixelCount,
  };

  factory InspectionResultData.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(json['scanTimestamp'] as String? ?? '');
    if (timestamp == null) {
      throw const FormatException('Waktu inspeksi tidak valid.');
    }
    return InspectionResultData(
      hasAssessment: json['hasAssessment'] as bool? ?? true,
      // Old automatically generated measurements are not verified measurements.
      hasMeasuredDiameter: json['hasMeasuredDiameter'] as bool? ?? false,
      hasMeasuredInclination: json['hasMeasuredInclination'] as bool? ?? false,
      hasPathologyAssessment: json['hasPathologyAssessment'] as bool? ?? false,
      imagePath: json['imagePath'] as String? ?? '',
      healthScore: (json['healthScore'] as num).toInt(),
      riskStatus: json['riskStatus'] as String,
      ronggaBatang: (json['ronggaBatang'] as num).toDouble(),
      sudutKemiringan: (json['sudutKemiringan'] as num).toDouble(),
      diameter: (json['diameter'] as num).toDouble(),
      isJamurPelapuk: json['isJamurPelapuk'] as bool,
      inspectionId: json['inspectionId'] as String,
      treeSpecies: json['treeSpecies'] as String,
      detectedCondition: json['detectedCondition'] as String,
      locationAddress: json['locationAddress'] as String,
      scanTimestamp: timestamp.toLocal(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      persentaseLuka: (json['persentaseLuka'] as num?)?.toDouble(),
      failurePotential: json['failurePotential'] as String? ?? 'Improbable',
      environmentalImpact: json['environmentalImpact'] as String? ?? 'Medium',
      riskAction: json['riskAction'] as String? ?? 'Pantau kondisi',
      isOfficerAssessed: json['isOfficerAssessed'] as bool? ?? false,
      modelRiskStatus: json['modelRiskStatus'] as String?,
      healthyPixelCount: (json['healthyPixelCount'] as num?)?.toInt() ?? 0,
      defectPixelCount: (json['defectPixelCount'] as num?)?.toInt() ?? 0,
    );
  }
}
