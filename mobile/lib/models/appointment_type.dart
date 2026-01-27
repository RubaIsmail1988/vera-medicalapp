class AppointmentType {
  final int id;
  final String typeName;
  final String? description;

  // NEW
  final int defaultDurationMinutes;

  AppointmentType({
    required this.id,
    required this.typeName,
    this.description,
    required this.defaultDurationMinutes,
  });

  factory AppointmentType.fromJson(Map<String, dynamic> json) {
    return AppointmentType(
      id: json['id'],
      typeName: json['type_name'],
      description: json['description'],
      defaultDurationMinutes: json['default_duration_minutes'] ?? 15,
    );
  }
}
