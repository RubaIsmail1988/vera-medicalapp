import 'dart:convert';

import '../models/doctor_specific_visit_type.dart';
import '/utils/api_exception.dart';
import 'auth_service.dart';

class DoctorSpecificVisitTypeService {
  final AuthService authService = AuthService();

  Future<List<DoctorSpecificVisitType>> fetchMine() async {
    final response = await authService.authorizedRequest(
      "/doctor-specific-visit-types/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map(
            (e) => DoctorSpecificVisitType.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required int durationMinutes,
    String? description,
  }) async {
    final body = <String, dynamic>{
      "name": name,
      "duration_minutes": durationMinutes,
      "description":
          (description ?? "").trim().isEmpty ? null : description!.trim(),
    };

    final response = await authService.authorizedRequest(
      "/doctor-specific-visit-types/",
      "POST",
      body: body,
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> update({
    required int id,
    required String name,
    required int durationMinutes,
    String? description,
  }) async {
    final body = <String, dynamic>{
      "name": name,
      "duration_minutes": durationMinutes,
      "description":
          (description ?? "").trim().isEmpty ? null : description!.trim(),
    };

    final response = await authService.authorizedRequest(
      "/doctor-specific-visit-types/$id/",
      "PATCH",
      body: body,
    );

    if (response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> delete(int id) async {
    final response = await authService.authorizedRequest(
      "/doctor-specific-visit-types/$id/",
      "DELETE",
    );

    if (response.statusCode == 204) return;

    throw ApiException(response.statusCode, response.body);
  }
}
