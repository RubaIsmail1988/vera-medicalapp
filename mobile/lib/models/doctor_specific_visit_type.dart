class DoctorSpecificVisitType {
  final int id;
  final int doctor;
  final String name;
  final int durationMinutes;
  final String? description;

  DoctorSpecificVisitType({
    required this.id,
    required this.doctor,
    required this.name,
    required this.durationMinutes,
    this.description,
  });

  factory DoctorSpecificVisitType.fromJson(Map<String, dynamic> json) {
    final rawDuration = json['duration_minutes'];
    final duration =
        rawDuration is int
            ? rawDuration
            : int.tryParse(rawDuration?.toString() ?? '') ?? 0;

    return DoctorSpecificVisitType(
      id: json['id'] as int,
      doctor: json['doctor'] as int,
      name: (json['name'] ?? '').toString(),
      durationMinutes: duration,
      description: json['description']?.toString(),
    );
  }
}
