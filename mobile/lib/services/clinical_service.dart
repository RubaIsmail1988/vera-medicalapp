// -----------------lib/services/clinical_service.dart----------------
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '/services/auth_service.dart';
import '/utils/constants.dart';

class ClinicalService {
  ClinicalService({required AuthService authService})
    : _authService = authService;

  final AuthService _authService;

  Uri _buildClinicalUri(String endpoint) {
    final cleanBase =
        clinicalBaseUrl.endsWith('/')
            ? clinicalBaseUrl.substring(0, clinicalBaseUrl.length - 1)
            : clinicalBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<http.Response> authorizedClinicalRequest(
    String endpoint,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send(String token) async {
      final url = _buildClinicalUri(endpoint);

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
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
          throw Exception("Invalid HTTP method");
      }
    }

    String? token = await _authService.getAccessToken();

    if (token == null) {
      await _authService.refreshToken();
      token = await _authService.getAccessToken();
    }

    if (token == null) {
      return http.Response('Unauthorized', 401);
    }

    final first = await send(token);

    if (first.statusCode == 401) {
      await _authService.refreshToken();
      final newToken = await _authService.getAccessToken();
      if (newToken == null) return first;
      return send(newToken);
    }

    return first;
  }

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// Backend contract (per ClinicalOrderListCreateView):
  /// - appointment is REQUIRED
  /// - client must NOT send patient (derived from appointment)
  /// - doctor is derived from token (or appointment for admin)
  ///
  /// orderCategory: "lab_test" | "medical_imaging"
  Future<http.Response> createOrder({
    required int appointmentId,
    required String orderCategory, // "lab_test" | "medical_imaging"
    required String title,
    String? details,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      "appointment": appointmentId,
      "order_category": orderCategory,
      "title": title,
      "details": details ?? "",
      // DO NOT send: patient, doctor
    };

    return authorizedClinicalRequest("/orders/", "POST", body: body);
  }

  Future<http.Response> listOrders() {
    return authorizedClinicalRequest("/orders/", "GET");
  }

  Future<http.Response> getOrderDetails(int orderId) {
    return authorizedClinicalRequest("/orders/$orderId/", "GET");
  }

  // ---------------------------------------------------------------------------
  // Files
  // ---------------------------------------------------------------------------

  Future<http.Response> listOrderFiles(int orderId) {
    return authorizedClinicalRequest("/orders/$orderId/files/", "GET");
  }

  Future<http.StreamedResponse> uploadFileToOrderBytes({
    required int orderId,
    required Uint8List bytes,
    required String filename,
  }) async {
    String? token = await _authService.getAccessToken();

    if (token == null) {
      await _authService.refreshToken();
      token = await _authService.getAccessToken();
    }

    if (token == null) {
      return http.StreamedResponse(const Stream.empty(), 401);
    }

    final url = _buildClinicalUri("/orders/$orderId/files/upload/");

    Future<http.StreamedResponse> sendMultipart(String bearerToken) async {
      final request = http.MultipartRequest("POST", url);
      request.headers["Authorization"] = "Bearer $bearerToken";
      request.headers["Accept"] = "application/json";

      // Backend expects multipart file field name: "file"
      request.files.add(
        http.MultipartFile.fromBytes("file", bytes, filename: filename),
      );

      return request.send();
    }

    final first = await sendMultipart(token);
    if (first.statusCode != 401) return first;

    await _authService.refreshToken();
    final newToken = await _authService.getAccessToken();
    if (newToken == null) return first;

    return sendMultipart(newToken);
  }

  Future<http.Response> approveFile(int fileId, {String? doctorNote}) {
    final Map<String, dynamic> body = {};
    if (doctorNote != null && doctorNote.trim().isNotEmpty) {
      body["doctor_note"] = doctorNote.trim();
    }
    return authorizedClinicalRequest(
      "/files/$fileId/approve/",
      "POST",
      body: body,
    );
  }

  Future<http.Response> rejectFile(int fileId, {required String doctorNote}) {
    return authorizedClinicalRequest(
      "/files/$fileId/reject/",
      "POST",
      body: <String, dynamic>{"doctor_note": doctorNote.trim()},
    );
  }

  /// Patient can delete ONLY pending files they uploaded (backend enforces).
  Future<http.Response> deleteMedicalFile(int fileId) {
    return authorizedClinicalRequest("/files/$fileId/", "DELETE");
  }

  // ---------------------------------------------------------------------------
  // Prescriptions
  // ---------------------------------------------------------------------------

  Future<http.Response> listPrescriptions() {
    return authorizedClinicalRequest("/prescriptions/", "GET");
  }

  Future<http.Response> getPrescriptionDetails(int prescriptionId) {
    return authorizedClinicalRequest("/prescriptions/$prescriptionId/", "GET");
  }

  /// Backend contract (per PrescriptionListCreateView):
  /// - appointment is REQUIRED
  /// - client must NOT send patient (derived from appointment)
  /// - doctor derived from token (or appointment for admin)
  /// - items are nested list under "items"
  ///
  /// items payload example:
  /// [
  ///   {"medicine_name": "...", "dosage": "...", "frequency": "...", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "instructions": "..."},
  /// ]
  Future<http.Response> createPrescription({
    required int appointmentId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    final Map<String, dynamic> body = {
      "appointment": appointmentId,
      "notes": notes ?? "",
      "items": items,
      // DO NOT send: patient, doctor
    };

    return authorizedClinicalRequest("/prescriptions/", "POST", body: body);
  }

  // ملاحظة: هذا endpoint غير موجود في urls.py الحالية عندك
  // لذا تركته مُعلّقًا كي لا تعتمد عليه بالخطأ.
  //
  // Future<http.Response> addPrescriptionItems({
  //   required int prescriptionId,
  //   required List<Map<String, dynamic>> items,
  // }) {
  //   final Map<String, dynamic> body = {"items": items};
  //   return authorizedClinicalRequest(
  //     "/prescriptions/$prescriptionId/items/",
  //     "POST",
  //     body: body,
  //   );
  // }

  // ---------------------------------------------------------------------------
  // Adherence
  // ---------------------------------------------------------------------------

  Future<http.Response> listAdherence() {
    return authorizedClinicalRequest("/adherence/", "GET");
  }

  Future<http.Response> createAdherence({
    required int prescriptionItemId,
    required String status, // taken | skipped
    required DateTime takenAt,
    String? note,
  }) {
    final Map<String, dynamic> body = <String, dynamic>{
      "prescription_item": prescriptionItemId,
      "status": status,
      "taken_at": takenAt.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) "note": note.trim(),
    };

    return authorizedClinicalRequest("/adherence/", "POST", body: body);
  }

  // ---------------------------------------------------------------------------
  // Aggregation (optional but useful)
  // GET /api/clinical/record/?patient_id=...
  // ---------------------------------------------------------------------------

  Future<http.Response> getClinicalRecordAggregation({required int patientId}) {
    final qp = Uri(queryParameters: {"patient_id": patientId.toString()}).query;
    return authorizedClinicalRequest("/record/?$qp", "GET");
  }
  // ---------------------------------------------------------------------------
  // Inbox (Polling)
  // GET /api/clinical/inbox/?since_id=...&limit=...
  // ---------------------------------------------------------------------------

  Future<http.Response> fetchInbox({int? sinceId, int limit = 50}) {
    final qp = <String, String>{
      "limit": limit.toString(),
      if (sinceId != null && sinceId > 0) "since_id": sinceId.toString(),
    };

    final query = Uri(queryParameters: qp).query;
    return authorizedClinicalRequest("/inbox/?$query", "GET");
  }
}
