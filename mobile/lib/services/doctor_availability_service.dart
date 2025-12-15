import 'dart:convert';

import '../models/doctor_availability.dart';
import 'auth_service.dart';

class DoctorAvailabilityService {
  final AuthService authService = AuthService();
  Future<List<DoctorAvailability>> fetchMine() async {
    final response = await authService.authorizedRequest(
      "/doctor-availabilities/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => DoctorAvailability.fromJson(e)).toList();
    }

    throw Exception(
      'Failed to load doctor availabilities: '
      '${response.statusCode} - ${response.body}',
    );
  }

  Future<void> create({
    required String dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final response = await authService.authorizedRequest(
      "/doctor-availabilities/",
      "POST",
      body: {
        "day_of_week": dayOfWeek,
        "start_time": startTime,
        "end_time": endTime,
      },
    );

    if (response.statusCode == 201) return;
    throw Exception('Create failed: ${response.statusCode} - ${response.body}');
  }

  Future<void> updateTimes({
    required int id,
    required String startTime,
    required String endTime,
  }) async {
    final response = await authService.authorizedRequest(
      "/doctor-availabilities/$id/",
      "PATCH",
      body: {"start_time": startTime, "end_time": endTime},
    );

    if (response.statusCode == 200) return;
    throw Exception('Update failed: ${response.statusCode} - ${response.body}');
  }

  Future<void> delete(int id) async {
    final response = await authService.authorizedRequest(
      "/doctor-availabilities/$id/",
      "DELETE",
    );

    if (response.statusCode == 204) return;
    throw Exception('Delete failed: ${response.statusCode} - ${response.body}');
  }
}
