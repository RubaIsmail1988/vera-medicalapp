import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/appointment.dart';
import '../models/appointment_create_request.dart';
import '../models/doctor_search_result.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

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

  /// يرجّع الـ payload كما هو (central + specific)
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
      return Appointment.fromJson(decoded);
    }

    throw ApiException(resp.statusCode, resp.body);
  }

  Future<Map<String, dynamic>> fetchDoctorSlots({
    required int doctorId,
    required String date, // "YYYY-MM-DD"
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
    String? status, // pending|confirmed|cancelled|no_show|all
    String? time, // upcoming|past|all
    String? preset, // today|next7|day
    String? date, // YYYY-MM-DD (when preset=day)
    String? fromDate, // YYYY-MM-DD
    String? toDate, // YYYY-MM-DD
  }) async {
    final qp = <String, String>{};

    // status
    final s = (status ?? '').trim();
    if (s.isNotEmpty && s != 'all') {
      qp['status'] = s;
    }

    // time
    final t = (time ?? '').trim();
    if (t.isNotEmpty && t != 'all') {
      // إذا بدك الافتراضي upcoming لا ترسله، أو أرسله صراحة - حسب قرارك
      qp['time'] = t; // upcoming|past
    } else if (t == 'all') {
      qp['time'] = 'all';
    }

    // preset (takes precedence conceptually; backend will decide)
    final p = (preset ?? '').trim();
    if (p.isNotEmpty) {
      qp['preset'] = p; // today|next7|day
      if (p == 'day') {
        final d = (date ?? '').trim();
        if (d.isNotEmpty) qp['date'] = d;
      }
    } else {
      // from/to only if no preset
      final f = (fromDate ?? '').trim();
      final to = (toDate ?? '').trim();
      if (f.isNotEmpty) qp['from'] = f;
      if (to.isNotEmpty) qp['to'] = to;
    }

    final query = qp.isEmpty ? '' : '?${Uri(queryParameters: qp).query}';
    final endpoint = "/my/$query";

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
        .map((e) => Appointment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> cancelAppointment({required int appointmentId}) async {
    final resp = await _authorizedAppointmentsRequest(
      "/$appointmentId/cancel/",
      "POST",
    );

    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }
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

    // confirm endpoint يرجّع 200 حتى لو already confirmed (idempotent)
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }
  }
}
