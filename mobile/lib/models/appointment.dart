class Appointment {
  final int id;
  final int patient;
  final String? patientName;

  final int doctor;
  final String? doctorName;

  final int appointmentType;
  final String? appointmentTypeName;

  final DateTime dateTime;
  final int durationMinutes;
  final String status;
  final String? notes;
  final DateTime createdAt;

  Appointment({
    required this.id,
    required this.patient,
    required this.patientName,
    required this.doctor,
    required this.doctorName,
    required this.appointmentType,
    required this.appointmentTypeName,
    required this.dateTime,
    required this.durationMinutes,
    required this.status,
    required this.notes,
    required this.createdAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final dur = json['duration_minutes'];
    return Appointment(
      id: json['id'] as int,
      patient: (json['patient'] as num).toInt(),
      patientName: json['patient_name'] as String?,
      doctor: (json['doctor'] as num).toInt(),
      doctorName: json['doctor_name'] as String?,
      appointmentType: (json['appointment_type'] as num).toInt(),
      appointmentTypeName: json['appointment_type_name'] as String?,
      dateTime: DateTime.parse(json['date_time'] as String),
      durationMinutes:
          (dur is num) ? dur.toInt() : int.tryParse(dur.toString()) ?? 0,
      status: (json['status'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
