class AppointmentType {
  final int id;
  final String typeName;
  final String? description;

  AppointmentType({required this.id, required this.typeName, this.description});

  factory AppointmentType.fromJson(Map<String, dynamic> json) {
    return AppointmentType(
      id: json['id'] as int,
      typeName: (json['type_name'] ?? '').toString(),
      description: json['description']?.toString(),
    );
  }
}
