class DoctorSearchResult {
  final int id;
  final String username;
  final String email;
  final String specialty;

  final int? governorateId;
  final String? governorateName;
  final int? experienceYears;

  DoctorSearchResult({
    required this.id,
    required this.username,
    required this.email,
    required this.specialty,
    this.governorateId,
    this.governorateName,
    this.experienceYears,
  });

  factory DoctorSearchResult.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return DoctorSearchResult(
      id: parseInt(json['id']) ?? 0,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      specialty: (json['specialty'] as String?) ?? '',
      governorateId: parseInt(json['governorate_id']),
      governorateName: json['governorate_name'] as String?,
      experienceYears: parseInt(json['experience_years']),
    );
  }
}
