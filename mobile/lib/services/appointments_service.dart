import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/appointment_create_request.dart';
import '../models/doctor_search_result.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../services/local_notifications_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String body;

  ApiException(this.statusCode, this.body);

  @override
  String toString() => "ApiException($statusCode): $body";
}

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

      switch (method.toUpperCase()) {
        case "GET":
          return http.get(url, headers: headers);
        case "POST":
          return http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "PUT":
          return http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "PATCH":
          return http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "DELETE":
          return http.delete(url, headers: headers);
        default:
          throw Exception("Invalid HTTP method: $method");
      }
    }

    String? token = await authService.getAccessToken();

    if (token == null) {
      await authService.refreshToken();
      token = await authService.getAccessToken();
    }

    if (token == null) {
      return http.Response('Unauthorized', 401);
    }

    final first = await send(token);

    if (first.statusCode == 401) {
      await authService.refreshToken();
      final newToken = await authService.getAccessToken();
      if (newToken == null) return first;
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

  // -------- helper to convert decoded to Map ------
  Map<String, dynamic> _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw Exception("Unexpected response format.");
  }

  // ---------------- API methods ----------------

  Future<List<DoctorSearchResult>> searchDoctors({
    required String query,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final resp = await _authorizedAppointmentsRequest(
      "/doctors/search/?q=${Uri.encodeComponent(q)}",
      "GET",
    );

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

    throw Exception("Unexpected response format.");
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

    throw Exception("Unexpected response format.");
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

    // NOTE: الجهاز الذي ينفّذ confirm قد لا يكون جهاز المريض،
    // لكن هذا يساعدنا بالاختبار عندما نؤكد على نفس الجهاز.
    // المريض سيحصل عليها أيضاً عبر fetchMyAppointments (sync).
    try {
      // الأفضل: إعادة fetch للموعد الواحد، لكن ما عنا endpoint لهذا الآن.
      // لذلك نعتمد على شاشة "مواعيدي" لتعمل sync بعد التأكيد.
    } catch (_) {}
  }

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

    throw Exception("Unexpected response format.");
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
