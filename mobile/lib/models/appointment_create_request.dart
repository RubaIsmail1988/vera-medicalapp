class AppointmentCreateRequest {
  final int doctorId;
  final int appointmentTypeId;

  final DateTime dateTime;

  final String? notes;

  // NEW (optional)
  final Map<String, dynamic>? triage;

  AppointmentCreateRequest({
    required this.doctorId,
    required this.appointmentTypeId,
    required this.dateTime,
    this.notes,
    this.triage, // NEW
  });

  Map<String, dynamic> toJson() {
    final local = dateTime; // keep as local

    return <String, dynamic>{
      'doctor_id': doctorId,
      'appointment_type_id': appointmentTypeId,
      'date_time': local.toIso8601String(), // no "Z"
      'notes': (notes ?? '').trim(),
      if (triage != null && triage!.isNotEmpty) 'triage': triage,
    };
  }
}
