import 'dart:convert';

import '../models/doctor_appointment_type.dart';
import 'auth_service.dart';

class DoctorAppointmentTypeService {
  final AuthService authService = AuthService();

  Future<List<DoctorAppointmentType>> fetchMine() async {
    final response = await authService.authorizedRequest(
      "/doctor-appointment-types/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => DoctorAppointmentType.fromJson(e)).toList();
    }

    throw Exception(
      'Failed to load doctor appointment types: ${response.statusCode}',
    );
  }

  Future<Map<String, dynamic>> create({
    required int appointmentTypeId,
    required int durationMinutes,
  }) async {
    final response = await authService.authorizedRequest(
      "/doctor-appointment-types/",
      "POST",
      body: {
        "appointment_type": appointmentTypeId,
        "duration_minutes": durationMinutes,
      },
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    final body = response.body.isNotEmpty ? response.body : "{}";
    throw Exception('Create failed: ${response.statusCode} - $body');
  }

  Future<void> delete(int id) async {
    final response = await authService.authorizedRequest(
      "/doctor-appointment-types/$id/",
      "DELETE",
    );

    if (response.statusCode == 204) return;
    throw Exception('Delete failed: ${response.statusCode}');
  }

  Future<void> updateDuration({
    required int id,
    required int durationMinutes,
  }) async {
    final response = await authService.authorizedRequest(
      "/doctor-appointment-types/$id/",
      "PATCH",
      body: {"duration_minutes": durationMinutes},
    );

    if (response.statusCode == 200) return;
    throw Exception('Update failed: ${response.statusCode} - ${response.body}');
  }
}
