class AppointmentCreateRequest {
  final int doctorId;
  final int appointmentTypeId;

  final DateTime dateTime;

  final String? notes;

  AppointmentCreateRequest({
    required this.doctorId,
    required this.appointmentTypeId,
    required this.dateTime,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    final DateTime utc = dateTime.isUtc ? dateTime : dateTime.toUtc();

    return {
      'doctor_id': doctorId,
      'appointment_type_id': appointmentTypeId,
      'date_time': utc.toIso8601String(), // ends with Z when utc
      'notes': (notes ?? '').trim(),
    };
  }
}
