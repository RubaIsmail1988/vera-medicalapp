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
    final DateTime utc = dateTime.isUtc ? dateTime : dateTime.toUtc();

    final data = <String, dynamic>{
      'doctor_id': doctorId,
      'appointment_type_id': appointmentTypeId,
      'date_time': utc.toIso8601String(), // ends with Z when utc
      'notes': (notes ?? '').trim(),
    };

    // NEW: only include triage if not null and not empty
    if (triage != null && triage!.isNotEmpty) {
      data['triage'] = triage;
    }

    return data;
  }
}
