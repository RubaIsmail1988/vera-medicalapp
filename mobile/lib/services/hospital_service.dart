import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../models/hospital.dart';

class HospitalService {
  final AuthService authService = AuthService();

  String extractErrorMessage(http.Response response) {
    final raw = response.body.toString().trim();
    if (raw.isEmpty) return 'HTTP ${response.statusCode}';

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        final detail = decoded['detail'];
        if (detail != null && detail.toString().trim().isNotEmpty) {
          return detail.toString();
        }

        for (final entry in decoded.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) {
            return v.first.toString();
          }
          if (v != null && v.toString().trim().isNotEmpty) {
            return v.toString();
          }
        }
      }

      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString();
      }
    } catch (_) {}

    final short = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
    return short;
  }

  Future<List<Hospital>> fetchHospitals() async {
    final response = await authService.authorizedRequest('/hospitals/', 'GET');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception(
      'Failed to load hospitals: ${extractErrorMessage(response)}',
    );
  }

  Future<Hospital> getHospital(int id) async {
    final response = await authService.authorizedRequest(
      '/hospitals/$id/',
      'GET',
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Hospital.fromJson(data);
    }

    throw Exception(
      'Failed to load hospital: ${extractErrorMessage(response)}',
    );
  }

  Future<http.Response> createHospital(Hospital hospital) {
    return authService.authorizedRequest(
      '/hospitals/',
      'POST',
      body: hospital.toJson(),
    );
  }

  Future<http.Response> updateHospital(Hospital hospital) {
    final hospitalId = hospital.id;
    if (hospitalId == null) {
      throw Exception('Hospital ID is required for update');
    }

    return authService.authorizedRequest(
      '/hospitals/$hospitalId/',
      'PUT',
      body: hospital.toJson(),
    );
  }

  Future<bool> deleteHospital(int id) async {
    final response = await authService.authorizedRequest(
      '/hospitals/$id/',
      'DELETE',
    );
    return response.statusCode == 204 || response.statusCode == 200;
  }
}
