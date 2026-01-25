import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/doctor_appointment_type.dart';
import '/utils/api_exception.dart';
import 'auth_service.dart';

class DoctorAppointmentTypeService {
  final AuthService authService = AuthService();

  // --------------------------------------------------
  // Fetch
  // --------------------------------------------------

  Future<List<DoctorAppointmentType>> fetchMine() async {
    http.Response response;

    try {
      response = await authService.authorizedRequest(
        "/doctor-appointment-types/",
        "GET",
      );
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is List) {
        return decoded
            .map(
              (e) => DoctorAppointmentType.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }

      throw const ApiException(500, 'Unexpected response format');
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

  // --------------------------------------------------
  // Create
  // --------------------------------------------------

  Future<Map<String, dynamic>> create({
    required int appointmentTypeId,
    required int durationMinutes,
  }) async {
    http.Response response;

    try {
      response = await authService.authorizedRequest(
        "/doctor-appointment-types/",
        "POST",
        body: {
          "appointment_type": appointmentTypeId,
          "duration_minutes": durationMinutes,
        },
      );
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

  // --------------------------------------------------
  // Update
  // --------------------------------------------------

  Future<void> updateDuration({
    required int id,
    required int durationMinutes,
  }) async {
    http.Response response;

    try {
      response = await authService.authorizedRequest(
        "/doctor-appointment-types/$id/",
        "PATCH",
        body: {"duration_minutes": durationMinutes},
      );
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }

    if (response.statusCode == 200) return;

    throw ApiExceptionUtils.fromResponse(response);
  }

  // --------------------------------------------------
  // Delete
  // --------------------------------------------------

  Future<void> delete(int id) async {
    http.Response response;

    try {
      response = await authService.authorizedRequest(
        "/doctor-appointment-types/$id/",
        "DELETE",
      );
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }

    if (response.statusCode == 204 || response.statusCode == 200) return;

    throw ApiExceptionUtils.fromResponse(response);
  }
}
