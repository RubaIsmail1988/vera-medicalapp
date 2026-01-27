// services/appointments_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/appointment_create_request.dart';
import '../models/doctor_search_result.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../services/local_notifications_service.dart';
import '/utils/api_exception.dart';

class AppointmentsService {
  final AuthService authService = AuthService();

  // ---------------- URL helpers ----------------

  Uri _buildAppointmentsUri(String endpoint) {
    final cleanBase =
        appointmentsBaseUrl.endsWith('/')
            ? appointmentsBaseUrl.substring(0, appointmentsBaseUrl.length - 1)
            : appointmentsBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  // ---------------- Authorized requests (appointments domain) ----------------

  Future<http.Response> _authorizedAppointmentsRequest(
    String endpoint,
    String method, {
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  }) async {
    Future<http.Response> send(String token) async {
      final url = _buildAppointmentsUri(endpoint);

      final headers = <String, String>{
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        if (extraHeaders != null) ...extraHeaders,
      };

      try {
        switch (method.toUpperCase()) {
          case "GET":
            return await http.get(url, headers: headers);

          case "POST":
            return await http.post(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );

          case "PUT":
            return await http.put(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );

          case "PATCH":
            return await http.patch(
              url,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );

          case "DELETE":
            return await http.delete(url, headers: headers);

          default:
            throw ApiException(400, "Invalid HTTP method: $method");
        }
      } catch (e) {
        if (ApiExceptionUtils.isNetworkException(e)) {
          throw ApiExceptionUtils.network(e);
        }
        rethrow;
      }
    }

    String? token = await authService.getAccessToken();

    // إذا لا يوجد توكن أصلًا → جرّب refresh
    if (token == null) {
      try {
        await authService.refreshToken();
      } catch (_) {
        // تجاهل: ممكن يكون لا إنترنت أو refresh فشل
      }
      token = await authService.getAccessToken();
    }

    // IMPORTANT: لا نرجّع Response "مزيف" — نرمي ApiException ليبقى موحّد
    if (token == null) {
      throw const ApiException(401, 'Unauthorized');
    }

    final first = await send(token);

    if (first.statusCode == 401) {
      try {
        await authService.refreshToken();
      } catch (_) {
        throw ApiException(first.statusCode, first.body);
      }

      final newToken = await authService.getAccessToken();
      if (newToken == null) {
        throw ApiException(first.statusCode, first.body);
      }

      return send(newToken);
    }

    return first;
  }

  // ------------- notification helper -------------
  Future<void> _syncLocalRemindersForAppointments(
    List<Appointment> items,
  ) async {
    final nowLocal = DateTime.now();

    for (final ap in items) {
      final startLocal = ap.dateTime.toLocal();

      // فقط المواعيد القادمة
      if (startLocal.isBefore(nowLocal)) {
        // قد يكون في تذكيرات قديمة — نلغيها احتياطياً
        try {
          await LocalNotificationsService.cancelAppointmentReminders(ap.id);
        } catch (_) {}
        continue;
      }

      final st = ap.status.trim().toLowerCase();

      // سياستنا الآن: confirmed فقط
      if (st == "confirmed") {
        await LocalNotificationsService.scheduleAppointmentReminders(
          appointmentId: ap.id,
          doctorName: ap.doctorName ?? "الطبيب",
          appointmentDateTimeLocal: startLocal,
        );
      } else {
        await LocalNotificationsService.cancelAppointmentReminders(ap.id);
      }
    }
  }

  /// Public helper:
  /// استدعِها من Splash/Login إذا بدك تضمن أن التذكيرات تنضبط فور فتح التطبيق
  /// حتى لو المستخدم ما فتح شاشة المواعيد.
  Future<void> syncMyRemindersNow() async {
    try {
      // نجلب القائمة الافتراضية (بدون فلاتر) حتى نضمن cleanup + scheduling صحيح
      await fetchMyAppointments();
    } catch (_) {
      // تجاهل: إذا ما في نت، ما بدنا نكسر التطبيق
    }
  }

  // -------- helper to convert decoded to Map ------
  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const ApiException(500, "Unexpected response format.");
  }

  // ---------------- API methods ----------------

  Future<List<DoctorSearchResult>> searchDoctors({
    required String query,
    int? governorateId,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final qp = <String, String>{
      "q": q,
      if (governorateId != null) "governorate_id": governorateId.toString(),
    };

    final endpoint = "/doctors/search/?${Uri(queryParameters: qp).query}";

    final resp = await _authorizedAppointmentsRequest(endpoint, "GET");

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    final List<dynamic> results =
        (decoded is Map && decoded["results"] is List)
            ? decoded["results"] as List<dynamic>
            : <dynamic>[];

    return results.map((e) => DoctorSearchResult.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> fetchDoctorVisitTypes({
    required int doctorId,
  }) async {
    final resp = await _authorizedAppointmentsRequest(
      "/doctors/$doctorId/visit-types/",
      "GET",
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw const ApiException(500, "Unexpected response format.");
  }

  Future<Appointment> createAppointment({
    required AppointmentCreateRequest request,
  }) async {
    final resp = await _authorizedAppointmentsRequest(
      "/",
      "POST",
      body: request.toJson(),
    );

    if (resp.statusCode == 201) {
      final decoded = jsonDecode(resp.body);
      final ap = Appointment.fromJson(_asMap(decoded));

      // IMPORTANT:
      // لا نعمل schedule هون بشكل موثوق لأن الموعد غالباً pending.
      // التذكيرات تُضبط عبر fetchMyAppointments (sync) بعد التأكيد.
      // ومع ذلك: نضمن تنظيف أي تذكيرات قديمة لنفس id.
      try {
        await LocalNotificationsService.cancelAppointmentReminders(ap.id);
      } catch (_) {}

      return ap;
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<Map<String, dynamic>> fetchDoctorSlots({
    required int doctorId,
    required String date,
    required int appointmentTypeId,
  }) async {
    final resp = await _authorizedAppointmentsRequest(
      "/doctors/$doctorId/slots/?date=${Uri.encodeComponent(date)}&appointment_type_id=$appointmentTypeId",
      "GET",
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map<String, dynamic>) return decoded;

    throw const ApiException(500, "Unexpected response format.");
  }

  Future<List<Appointment>> fetchMyAppointments({
    String? status,
    String? time,
    String? preset,
    String? date,
    String? fromDate,
    String? toDate,
  }) async {
    final qp = <String, String>{};

    final s = (status ?? '').trim();
    if (s.isNotEmpty && s != 'all') qp['status'] = s;

    final t = (time ?? '').trim();
    if (t.isNotEmpty) qp['time'] = t;

    final p = (preset ?? '').trim();
    if (p.isNotEmpty) {
      qp['preset'] = p;
      if (p == 'day') {
        final d = (date ?? '').trim();
        if (d.isNotEmpty) qp['date'] = d;
      }
    } else {
      final f = (fromDate ?? '').trim();
      final to = (toDate ?? '').trim();
      if (f.isNotEmpty) qp['from'] = f;
      if (to.isNotEmpty) qp['to'] = to;
    }

    final endpoint =
        qp.isEmpty ? "/my/" : "/my/?${Uri(queryParameters: qp).query}";

    final resp = await _authorizedAppointmentsRequest(endpoint, "GET");

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    final List<dynamic> results =
        (decoded is Map && decoded["results"] is List)
            ? decoded["results"] as List
            : <dynamic>[];

    final items =
        results
            .whereType<Map>()
            .map((e) => Appointment.fromJson(Map<String, dynamic>.from(e)))
            .toList();

    // Sync reminders (confirmed only)
    try {
      await _syncLocalRemindersForAppointments(items);
    } catch (_) {}

    return items;
  }

  Future<void> cancelAppointment({required int appointmentId}) async {
    final resp = await _authorizedAppointmentsRequest(
      "/$appointmentId/cancel/",
      "POST",
    );

    if (resp.statusCode != 200 && resp.statusCode != 204) {
      throw ApiException(resp.statusCode, resp.body);
    }

    try {
      await LocalNotificationsService.cancelAppointmentReminders(appointmentId);
    } catch (_) {}
  }

  Future<void> markNoShow({required int appointmentId}) async {
    final resp = await _authorizedAppointmentsRequest(
      "/$appointmentId/mark-no-show/",
      "POST",
    );

    if (resp.statusCode == 200) return;
    throw ApiException(resp.statusCode, resp.body);
  }

  Future<void> confirmAppointment({required int appointmentId}) async {
    final resp = await _authorizedAppointmentsRequest(
      "/$appointmentId/confirm/",
      "POST",
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    try {
      await fetchMyAppointments();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Slots-range (raw Map) — keep for backward compatibility
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> fetchDoctorSlotsRange({
    required int doctorId,
    required int appointmentTypeId,
    String? fromDate,
    String? toDate,
    int? days,
  }) async {
    final qp = <String, String>{
      'appointment_type_id': appointmentTypeId.toString(),
    };

    if (days != null) {
      qp['days'] = days.toString();
    } else {
      if (fromDate != null && fromDate.trim().isNotEmpty) {
        qp['from_date'] = fromDate.trim();
      }
      if (toDate != null && toDate.trim().isNotEmpty) {
        qp['to_date'] = toDate.trim();
      }
    }

    final endpoint =
        "/doctors/$doctorId/slots-range/?${Uri(queryParameters: qp).query}";

    final resp = await _authorizedAppointmentsRequest(endpoint, "GET");

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    return Map<String, dynamic>.from(jsonDecode(resp.body));
  }

  // ---------------------------------------------------------------------------
  // Slots-range (typed) — includes rebooking_priority
  // ---------------------------------------------------------------------------

  Future<DoctorSlotsRangeResponseDto> fetchDoctorSlotsRangeDto({
    required int doctorId,
    required int appointmentTypeId,
    String? fromDate,
    String? toDate,
    int? days,
  }) async {
    final raw = await fetchDoctorSlotsRange(
      doctorId: doctorId,
      appointmentTypeId: appointmentTypeId,
      fromDate: fromDate,
      toDate: toDate,
      days: days,
    );
    return DoctorSlotsRangeResponseDto.fromJson(raw);
  }

  // ---------------------------------------------------------------------------
  // Urgent Requests (NEW)
  // ---------------------------------------------------------------------------

  Future<UrgentRequestDto> createUrgentRequest({
    required int doctorId,
    required int appointmentTypeId,
    String? notes,
    Map<String, dynamic>? triage,
  }) async {
    final payload = <String, dynamic>{
      "doctor_id": doctorId,
      "appointment_type_id": appointmentTypeId,
      if (notes != null) "notes": notes,
      if (triage != null) "triage": triage,
    };

    final resp = await _authorizedAppointmentsRequest(
      "/urgent-requests/",
      "POST",
      body: payload,
    );

    if (resp.statusCode == 201) {
      return UrgentRequestDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<List<UrgentRequestListItemDto>> fetchMyUrgentRequests({
    String? status,
  }) async {
    final qp = <String, String>{};
    final st = (status ?? "").trim();
    if (st.isNotEmpty) qp["status"] = st;

    final endpoint =
        qp.isEmpty
            ? "/urgent-requests/my/"
            : "/urgent-requests/my/?${Uri(queryParameters: qp).query}";

    final resp = await _authorizedAppointmentsRequest(endpoint, "GET");

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    final List<dynamic> results =
        (decoded is Map && decoded["results"] is List)
            ? decoded["results"] as List
            : <dynamic>[];

    return results
        .whereType<Map>()
        .map(
          (e) =>
              UrgentRequestListItemDto.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<UrgentRequestActionResultDto> rejectUrgentRequest({
    required int urgentRequestId,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      if (reason != null && reason.trim().isNotEmpty) "reason": reason.trim(),
    };

    final resp = await _authorizedAppointmentsRequest(
      "/urgent-requests/$urgentRequestId/reject/",
      "POST",
      body: payload.isEmpty ? null : payload,
    );

    if (resp.statusCode == 200) {
      return UrgentRequestActionResultDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<UrgentRequestScheduleResultDto> scheduleUrgentRequest({
    required int urgentRequestId,
    required String dateTimeIso,
    String? notes,
    bool allowOverbook = false,
  }) async {
    final payload = <String, dynamic>{
      "date_time": dateTimeIso,
      "allow_overbook": allowOverbook,
      if (notes != null) "notes": notes,
    };

    final resp = await _authorizedAppointmentsRequest(
      "/urgent-requests/$urgentRequestId/schedule/",
      "POST",
      body: payload,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return UrgentRequestScheduleResultDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  // ---------------------------------------------------------------------------
  // Emergency Absence (NEW) — doctor only
  // ---------------------------------------------------------------------------

  Future<EmergencyAbsenceResultDto> createEmergencyAbsence({
    required String startTimeIso,
    required String endTimeIso,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      "start_time": startTimeIso,
      "end_time": endTimeIso,
      if (notes != null) "notes": notes,
    };

    final resp = await _authorizedAppointmentsRequest(
      "/absences/emergency/",
      "POST",
      body: payload,
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return EmergencyAbsenceResultDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  // ---------------- Doctor Absences (CRUD) ----------------

  Future<List<DoctorAbsenceDto>> fetchDoctorAbsences() async {
    final resp = await _authorizedAppointmentsRequest("/absences/", "GET");

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is List) {
      return decoded
          .map((e) => DoctorAbsenceDto.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw const ApiException(500, "Unexpected response format.");
  }

  Future<DoctorAbsenceDto> createDoctorAbsence({
    required Map<String, dynamic> payload,
  }) async {
    final resp = await _authorizedAppointmentsRequest(
      "/absences/",
      "POST",
      body: payload,
    );

    if (resp.statusCode == 201) {
      return DoctorAbsenceDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<DoctorAbsenceDto> updateDoctorAbsence({
    required int absenceId,
    required Map<String, dynamic> payload,
  }) async {
    final resp = await _authorizedAppointmentsRequest(
      "/absences/$absenceId/",
      "PATCH",
      body: payload,
    );

    if (resp.statusCode == 200) {
      return DoctorAbsenceDto.fromJson(
        Map<String, dynamic>.from(jsonDecode(resp.body)),
      );
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<void> deleteDoctorAbsence({required int absenceId}) async {
    final resp = await _authorizedAppointmentsRequest(
      "/absences/$absenceId/",
      "DELETE",
    );

    if (resp.statusCode == 204) return;
    throw ApiException(resp.statusCode, resp.body);
  }
}

// -----------------------------------------------------------------------------
// DTOs
// -----------------------------------------------------------------------------

class DoctorAbsenceDto {
  final int id;
  final int doctor;
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final String? notes;

  DoctorAbsenceDto({
    required this.id,
    required this.doctor,
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.notes,
  });

  factory DoctorAbsenceDto.fromJson(Map<String, dynamic> json) {
    return DoctorAbsenceDto(
      id: (json['id'] as num).toInt(),
      doctor: (json['doctor'] as num).toInt(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      type: (json['type'] as String?) ?? 'planned',
      notes: json['notes'] as String?,
    );
  }
}

class RebookingPriorityDto {
  final bool active;
  final DateTime expiresAt;

  RebookingPriorityDto({required this.active, required this.expiresAt});

  factory RebookingPriorityDto.fromJson(Map<String, dynamic> json) {
    return RebookingPriorityDto(
      active: json["active"] == true,
      expiresAt: DateTime.parse(json["expires_at"] as String),
    );
  }
}

class DoctorSlotsRangeDayDto {
  final String date; // YYYY-MM-DD
  final String availabilityStart; // HH:MM
  final String availabilityEnd; // HH:MM
  final List<String> slots; // ["09:00", ...]

  DoctorSlotsRangeDayDto({
    required this.date,
    required this.availabilityStart,
    required this.availabilityEnd,
    required this.slots,
  });

  factory DoctorSlotsRangeDayDto.fromJson(Map<String, dynamic> json) {
    final availability =
        (json["availability"] is Map)
            ? Map<String, dynamic>.from(json["availability"] as Map)
            : <String, dynamic>{};

    final rawSlots =
        (json["slots"] is List) ? (json["slots"] as List) : const [];

    return DoctorSlotsRangeDayDto(
      date: (json["date"] as String?) ?? "",
      availabilityStart: (availability["start"] as String?) ?? "",
      availabilityEnd: (availability["end"] as String?) ?? "",
      slots: rawSlots.map((e) => e.toString()).toList(),
    );
  }
}

class DoctorSlotsRangeResponseDto {
  final int doctorId;
  final int appointmentTypeId;
  final int durationMinutes;
  final String timezone;
  final String rangeFrom; // YYYY-MM-DD
  final String rangeTo; // YYYY-MM-DD
  final List<DoctorSlotsRangeDayDto> days;
  final RebookingPriorityDto? rebookingPriority;

  DoctorSlotsRangeResponseDto({
    required this.doctorId,
    required this.appointmentTypeId,
    required this.durationMinutes,
    required this.timezone,
    required this.rangeFrom,
    required this.rangeTo,
    required this.days,
    required this.rebookingPriority,
  });

  factory DoctorSlotsRangeResponseDto.fromJson(Map<String, dynamic> json) {
    final rangeMap =
        (json["range"] is Map)
            ? Map<String, dynamic>.from(json["range"] as Map)
            : <String, dynamic>{};

    final rawDays = (json["days"] is List) ? (json["days"] as List) : const [];

    RebookingPriorityDto? priority;
    if (json["rebooking_priority"] is Map) {
      priority = RebookingPriorityDto.fromJson(
        Map<String, dynamic>.from(json["rebooking_priority"] as Map),
      );
    }

    return DoctorSlotsRangeResponseDto(
      doctorId: (json["doctor_id"] as num).toInt(),
      appointmentTypeId: (json["appointment_type_id"] as num).toInt(),
      durationMinutes: (json["duration_minutes"] as num).toInt(),
      timezone: (json["timezone"] as String?) ?? "",
      rangeFrom: (rangeMap["from"] as String?) ?? "",
      rangeTo: (rangeMap["to"] as String?) ?? "",
      days:
          rawDays
              .whereType<Map>()
              .map(
                (e) => DoctorSlotsRangeDayDto.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
      rebookingPriority: priority,
    );
  }
}

class UrgentRequestDto {
  final int id;
  final int patient;
  final int doctor;
  final int appointmentType;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final Map<String, dynamic>? triage; // may be null

  UrgentRequestDto({
    required this.id,
    required this.patient,
    required this.doctor,
    required this.appointmentType,
    required this.status,
    required this.notes,
    required this.createdAt,
    required this.triage,
  });

  factory UrgentRequestDto.fromJson(Map<String, dynamic> json) {
    return UrgentRequestDto(
      id: (json["id"] as num).toInt(),
      patient: (json["patient"] as num).toInt(),
      doctor: (json["doctor"] as num).toInt(),
      appointmentType: (json["appointment_type"] as num).toInt(),
      status: (json["status"] as String?) ?? "open",
      notes: json["notes"] as String?,
      createdAt: DateTime.parse(json["created_at"] as String),
      triage:
          (json["triage"] is Map)
              ? Map<String, dynamic>.from(json["triage"] as Map)
              : null,
    );
  }
}

class UrgentRequestListItemDto {
  final int id;
  final int patient;
  final String? patientName;
  final int doctor;
  final String? doctorName;
  final int appointmentType;
  final String? appointmentTypeName;

  final String? symptomsText;
  final String? temperatureC;
  final int? bpSystolic;
  final int? bpDiastolic;
  final int? heartRate;

  final int? score;
  final int? confidence;
  final List<dynamic> missingFields;
  final String? scoreVersion;

  final String? notes;
  final String status;

  final DateTime createdAt;
  final DateTime? handledAt;

  final int? handledBy;
  final String? rejectedReason;

  // NEW: clarify how it was handled
  final String? handledType; // "scheduled" | "rejected" | null
  final int? scheduledAppointmentId;

  UrgentRequestListItemDto({
    required this.id,
    required this.patient,
    required this.patientName,
    required this.doctor,
    required this.doctorName,
    required this.appointmentType,
    required this.appointmentTypeName,
    required this.symptomsText,
    required this.temperatureC,
    required this.bpSystolic,
    required this.bpDiastolic,
    required this.heartRate,
    required this.score,
    required this.confidence,
    required this.missingFields,
    required this.scoreVersion,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
    required this.rejectedReason,
    required this.handledType,
    required this.scheduledAppointmentId,
  });

  factory UrgentRequestListItemDto.fromJson(Map<String, dynamic> json) {
    final mf =
        (json["missing_fields"] is List)
            ? (json["missing_fields"] as List)
            : <dynamic>[];

    return UrgentRequestListItemDto(
      id: (json["id"] as num).toInt(),
      patient: (json["patient"] as num).toInt(),
      patientName: json["patient_name"] as String?,
      doctor: (json["doctor"] as num).toInt(),
      doctorName: json["doctor_name"] as String?,
      appointmentType: (json["appointment_type"] as num).toInt(),
      appointmentTypeName: json["appointment_type_name"] as String?,
      symptomsText: json["symptoms_text"] as String?,
      temperatureC: json["temperature_c"]?.toString(),
      bpSystolic:
          (json["bp_systolic"] is num)
              ? (json["bp_systolic"] as num).toInt()
              : null,
      bpDiastolic:
          (json["bp_diastolic"] is num)
              ? (json["bp_diastolic"] as num).toInt()
              : null,
      heartRate:
          (json["heart_rate"] is num)
              ? (json["heart_rate"] as num).toInt()
              : null,
      score: (json["score"] is num) ? (json["score"] as num).toInt() : null,
      confidence:
          (json["confidence"] is num)
              ? (json["confidence"] as num).toInt()
              : null,
      missingFields: mf,
      scoreVersion: json["score_version"] as String?,
      notes: json["notes"] as String?,
      status: (json["status"] as String?) ?? "open",
      createdAt: DateTime.parse(json["created_at"] as String),
      handledAt:
          (json["handled_at"] is String)
              ? DateTime.parse(json["handled_at"] as String)
              : null,
      handledBy:
          (json["handled_by"] is num)
              ? (json["handled_by"] as num).toInt()
              : null,
      rejectedReason: json["rejected_reason"] as String?,

      // NEW
      handledType: (json["handled_type"] as String?)?.trim(),
      scheduledAppointmentId:
          (json["scheduled_appointment_id"] is num)
              ? (json["scheduled_appointment_id"] as num).toInt()
              : null,
    );
  }
}

class UrgentRequestActionResultDto {
  final int id;
  final String status;
  final DateTime? handledAt;
  final String? rejectedReason;

  final String? handledType;
  final int? scheduledAppointmentId;

  UrgentRequestActionResultDto({
    required this.id,
    required this.status,
    required this.handledAt,
    required this.rejectedReason,
    required this.handledType,
    required this.scheduledAppointmentId,
  });

  factory UrgentRequestActionResultDto.fromJson(Map<String, dynamic> json) {
    return UrgentRequestActionResultDto(
      id: (json["id"] as num).toInt(),
      status: (json["status"] as String?) ?? "",
      handledAt:
          (json["handled_at"] is String)
              ? DateTime.parse(json["handled_at"] as String)
              : null,
      rejectedReason: json["rejected_reason"] as String?,
      handledType: (json["handled_type"] as String?)?.trim(),
      scheduledAppointmentId:
          (json["scheduled_appointment_id"] is num)
              ? (json["scheduled_appointment_id"] as num).toInt()
              : null,
    );
  }
}

class ScheduledAppointmentMiniDto {
  final int id;
  final int patient;
  final int doctor;
  final int appointmentType;
  final DateTime dateTime;
  final int? durationMinutes;
  final String status;
  final String? notes;

  ScheduledAppointmentMiniDto({
    required this.id,
    required this.patient,
    required this.doctor,
    required this.appointmentType,
    required this.dateTime,
    required this.durationMinutes,
    required this.status,
    required this.notes,
  });

  factory ScheduledAppointmentMiniDto.fromJson(Map<String, dynamic> json) {
    return ScheduledAppointmentMiniDto(
      id: (json["id"] as num).toInt(),
      patient: (json["patient"] as num).toInt(),
      doctor: (json["doctor"] as num).toInt(),
      appointmentType: (json["appointment_type"] as num).toInt(),
      dateTime: DateTime.parse(json["date_time"] as String),
      durationMinutes:
          (json["duration_minutes"] is num)
              ? (json["duration_minutes"] as num).toInt()
              : null,
      status: (json["status"] as String?) ?? "",
      notes: json["notes"] as String?,
    );
  }
}

class UrgentRequestScheduleResultDto {
  final UrgentRequestActionResultDto urgentRequest;
  final ScheduledAppointmentMiniDto appointment;

  UrgentRequestScheduleResultDto({
    required this.urgentRequest,
    required this.appointment,
  });

  factory UrgentRequestScheduleResultDto.fromJson(Map<String, dynamic> json) {
    final ur =
        (json["urgent_request"] is Map)
            ? Map<String, dynamic>.from(json["urgent_request"] as Map)
            : <String, dynamic>{};

    final ap =
        (json["appointment"] is Map)
            ? Map<String, dynamic>.from(json["appointment"] as Map)
            : <String, dynamic>{};

    return UrgentRequestScheduleResultDto(
      urgentRequest: UrgentRequestActionResultDto.fromJson(ur),
      appointment: ScheduledAppointmentMiniDto.fromJson(ap),
    );
  }
}

class EmergencyAbsenceResultDto {
  final DoctorAbsenceDto absence;
  final List<int> cancelledAppointments;
  final List<int> tokensIssuedForPatients;
  final DateTime tokenExpiresAt;

  EmergencyAbsenceResultDto({
    required this.absence,
    required this.cancelledAppointments,
    required this.tokensIssuedForPatients,
    required this.tokenExpiresAt,
  });

  factory EmergencyAbsenceResultDto.fromJson(Map<String, dynamic> json) {
    final absenceMap =
        (json["absence"] is Map)
            ? Map<String, dynamic>.from(json["absence"] as Map)
            : <String, dynamic>{};

    final cancelled =
        (json["cancelled_appointments"] is List)
            ? (json["cancelled_appointments"] as List)
                .map((e) => (e as num).toInt())
                .toList()
            : <int>[];

    final tokens =
        (json["tokens_issued_for_patients"] is List)
            ? (json["tokens_issued_for_patients"] as List)
                .map((e) => (e as num).toInt())
                .toList()
            : <int>[];

    return EmergencyAbsenceResultDto(
      absence: DoctorAbsenceDto.fromJson(absenceMap),
      cancelledAppointments: cancelled,
      tokensIssuedForPatients: tokens,
      tokenExpiresAt: DateTime.parse(json["token_expires_at"] as String),
    );
  }
}
