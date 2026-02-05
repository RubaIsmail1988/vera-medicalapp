import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '/services/auth_service.dart';
import '/utils/api_exception.dart';
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
            throw Exception("Invalid HTTP method");
        }
      } on SocketException catch (e) {
        throw ApiExceptionUtils.network(e);
      } on http.ClientException catch (e) {
        throw ApiExceptionUtils.network(e);
      }
    }

    String? token = await _authService.getAccessToken();

    if (token == null || token.trim().isEmpty) {
      await _authService.refreshToken();
      token = await _authService.getAccessToken();
    }

    if (token == null || token.trim().isEmpty) {
      throw const ApiException(401, 'Unauthorized');
    }

    final first = await send(token);

    if (first.statusCode == 401) {
      await _authService.refreshToken();
      final newToken = await _authService.getAccessToken();
      if (newToken == null) {
        throw ApiExceptionUtils.fromResponse(first);
      }
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

  Future<http.Response> uploadFileToOrderBytesResponse({
    required int orderId,
    required Uint8List bytes,
    required String filename,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final streamed = await uploadFileToOrderBytes(
      orderId: orderId,
      bytes: bytes,
      filename: filename,
    ).timeout(timeout);

    final response = await http.Response.fromStream(streamed);

    // نجاح ممكن يكون 200/201/204 وبعضها body فاضي -> لازم نرجع Response طبيعي
    if (response.statusCode == 204) {
      return http.Response('', 204, headers: response.headers);
    }

    return response;
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

  Future<http.Response> createPrescription({
    required int appointmentId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    _validatePrescriptionItemsDates(items);

    final Map<String, dynamic> body = {
      "appointment": appointmentId,
      "notes": notes ?? "",
      "items": items,
    };

    return authorizedClinicalRequest("/prescriptions/", "POST", body: body);
  }

  void _validatePrescriptionItemsDates(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final startRaw = (item['start_date'] ?? '').toString().trim();
      final endRaw = (item['end_date'] ?? '').toString().trim();

      if (startRaw.isEmpty || endRaw.isEmpty) continue;

      DateTime? start;
      DateTime? end;

      try {
        start = DateTime.parse(startRaw);
        end = DateTime.parse(endRaw);
      } catch (_) {
        // نخليها خطأ واضح للمستخدم بدل ما يطلع parsing غامض
        throw const ApiException(
          400,
          '{"detail":"صيغة تاريخ البداية/النهاية غير صحيحة. استخدم YYYY-MM-DD."}',
        );
      }

      // شرطك المطلوب: النهاية أكبر من البداية (strictly greater)
      if (!end.isAfter(start)) {
        throw const ApiException(
          400,
          '{"detail":"تاريخ النهاية يجب أن يكون بعد تاريخ البداية."}',
        );
      }
    }
  }

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
  // ---------------------------------------------------------------------------
  // Patient Advice Cards
  // GET /api/clinical/patients/<id>/advice/
  // ---------------------------------------------------------------------------

  Future<http.Response> fetchPatientAdviceCards({required int patientId}) {
    return authorizedClinicalRequest("/patients/$patientId/advice/", "GET");
  }
}
