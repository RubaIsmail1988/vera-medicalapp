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

  // NEW flags from backend
  final bool hasAnyOrders; // أي طلبات (تحاليل/صور) مرتبطة بالموعد
  final bool hasOpenOrders; // هل يوجد طلبات بحالة open

  // NEW: triage (optional; doctor sees it, patient might get null)
  final TriageAssessmentDto? triage;

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
    required this.hasAnyOrders,
    required this.hasOpenOrders,
    required this.triage,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final dur = json['duration_minutes'];

    bool asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = (v?.toString() ?? '').trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    TriageAssessmentDto? triage;
    final triageRaw = json['triage'];
    if (triageRaw is Map) {
      triage = TriageAssessmentDto.fromJson(
        Map<String, dynamic>.from(triageRaw),
      );
    }

    return Appointment(
      id: (json['id'] as num).toInt(),
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

      // NEW: support both snake_case and camelCase just in case
      hasAnyOrders: asBool(json['has_any_orders'] ?? json['hasAnyOrders']),
      hasOpenOrders: asBool(json['has_open_orders'] ?? json['hasOpenOrders']),

      triage: triage,
    );
  }
}

class TriageAssessmentDto {
  final String? symptomsText;
  final String? temperatureC; // backend sends "38.2" or null
  final int? bpSystolic;
  final int? bpDiastolic;
  final int? heartRate;

  final int score; // 1..10
  final int? confidence; // 0..100 (nullable in backend)
  final List<dynamic> missingFields;
  final String scoreVersion;
  final DateTime createdAt;

  TriageAssessmentDto({
    required this.symptomsText,
    required this.temperatureC,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.heartRate,
    required this.score,
    required this.confidence,
    required this.missingFields,
    required this.scoreVersion,
    required this.createdAt,
  });

  factory TriageAssessmentDto.fromJson(Map<String, dynamic> json) {
    int? asIntOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return TriageAssessmentDto(
      symptomsText: json['symptoms_text'] as String?,
      temperatureC: json['temperature_c']?.toString(),
      bpSystolic: asIntOrNull(json['bp_systolic']),
      bpDiastolic: asIntOrNull(json['bp_diastolic']),
      heartRate: asIntOrNull(json['heart_rate']),
      score: (json['score'] as num).toInt(),
      confidence: asIntOrNull(json['confidence']),
      missingFields:
          (json['missing_fields'] is List)
              ? (json['missing_fields'] as List)
              : const [],
      scoreVersion: (json['score_version'] as String?) ?? 'triage_v1',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
