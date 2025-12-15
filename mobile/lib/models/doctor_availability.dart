class DoctorAvailability {
  final int id;
  final int doctor;
  final String dayOfWeek;
  final String startTime; // "HH:mm:ss"
  final String endTime; // "HH:mm:ss"

  DoctorAvailability({
    required this.id,
    required this.doctor,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    return DoctorAvailability(
      id: json['id'] as int,
      doctor: json['doctor'] as int,
      dayOfWeek: (json['day_of_week'] ?? '').toString(),
      startTime: (json['start_time'] ?? '').toString(),
      endTime: (json['end_time'] ?? '').toString(),
    );
  }
}
