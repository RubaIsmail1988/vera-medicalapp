class DoctorAppointmentType {
  final int id;
  final int doctor;
  final int appointmentType;
  final int durationMinutes;

  DoctorAppointmentType({
    required this.id,
    required this.doctor,
    required this.appointmentType,
    required this.durationMinutes,
  });

  factory DoctorAppointmentType.fromJson(Map<String, dynamic> json) {
    return DoctorAppointmentType(
      id: json['id'] as int,
      doctor: json['doctor'] as int,
      appointmentType: json['appointment_type'] as int,
      durationMinutes: json['duration_minutes'] as int,
    );
  }
}
