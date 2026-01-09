class DoctorSearchResult {
  final int id;
  final String username;
  final String email;
  final String specialty;

  DoctorSearchResult({
    required this.id,
    required this.username,
    required this.email,
    required this.specialty,
  });

  factory DoctorSearchResult.fromJson(Map<String, dynamic> json) {
    return DoctorSearchResult(
      id: json['id'] as int,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      specialty: (json['specialty'] as String?) ?? '',
    );
  }
}
