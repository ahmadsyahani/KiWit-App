class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String jobTitle;
  final String nip;
  final String rayon;
  final String instansi;
  final int inspectedTreesCount;
  final int reportsCount;
  final bool isSync;
  final String? avatarUrl;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.jobTitle = 'Petugas Lapangan DLH Surabaya',
    this.nip = '19850312 201001 1 004',
    this.rayon = 'Rayon 3 — Sukolilo',
    this.instansi = 'DLH Kota Surabaya',
    this.inspectedTreesCount = 0,
    this.reportsCount = 0,
    this.isSync = true,
    this.avatarUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? (json['fullName'] as String? ?? 'Petugas DLH'),
      jobTitle: json['job_title'] as String? ?? (json['jobTitle'] as String? ?? 'Petugas Lapangan DLH Surabaya'),
      nip: json['nip'] as String? ?? '19850312 201001 1 004',
      rayon: json['rayon'] as String? ?? 'Rayon 3 — Sukolilo',
      instansi: json['instansi'] as String? ?? 'DLH Kota Surabaya',
      inspectedTreesCount: (json['inspected_trees_count'] ?? json['inspectedTreesCount'] ?? 348) as int,
      reportsCount: (json['reports_count'] ?? json['reportsCount'] ?? 18) as int,
      isSync: (json['is_sync'] ?? json['isSync'] ?? true) as bool,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'job_title': jobTitle,
      'nip': nip,
      'rayon': rayon,
      'instansi': instansi,
      'inspected_trees_count': inspectedTreesCount,
      'reports_count': reportsCount,
      'is_sync': isSync,
      'avatar_url': avatarUrl,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? jobTitle,
    String? nip,
    String? rayon,
    String? instansi,
    int? inspectedTreesCount,
    int? reportsCount,
    bool? isSync,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      jobTitle: jobTitle ?? this.jobTitle,
      nip: nip ?? this.nip,
      rayon: rayon ?? this.rayon,
      instansi: instansi ?? this.instansi,
      inspectedTreesCount: inspectedTreesCount ?? this.inspectedTreesCount,
      reportsCount: reportsCount ?? this.reportsCount,
      isSync: isSync ?? this.isSync,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
