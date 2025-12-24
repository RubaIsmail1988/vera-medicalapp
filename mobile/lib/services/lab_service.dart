import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../models/lab.dart';

class LabService {
  final AuthService authService = AuthService();

  String extractErrorMessage(http.Response response) {
    final raw = response.body.toString().trim();
    if (raw.isEmpty) return 'HTTP ${response.statusCode}';

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        // شائع في DRF: {"detail": "..."} أو {"email":["..."]} أو {"non_field_errors":["..."]}
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
    } catch (_) {
      // body ليس JSON
    }

    // fallback: قصّ النص لتجنّب سبام
    final short = raw.length > 180 ? '${raw.substring(0, 180)}…' : raw;
    return short;
  }

  Future<List<Lab>> fetchLabs() async {
    final response = await authService.authorizedRequest('/labs/', 'GET');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Lab.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw Exception('Failed to load labs: ${extractErrorMessage(response)}');
  }

  Future<Lab> getLab(int id) async {
    final response = await authService.authorizedRequest('/labs/$id/', 'GET');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Lab.fromJson(data);
    }

    throw Exception('Failed to load lab: ${extractErrorMessage(response)}');
  }

  Future<http.Response> createLab(Lab lab) {
    return authService.authorizedRequest('/labs/', 'POST', body: lab.toJson());
  }

  Future<http.Response> updateLab(Lab lab) {
    final labId = lab.id;
    if (labId == null) {
      throw Exception('Lab ID is required for update');
    }

    return authService.authorizedRequest(
      '/labs/$labId/',
      'PUT',
      body: lab.toJson(),
    );
  }

  Future<bool> deleteLab(int id) async {
    final response = await authService.authorizedRequest(
      '/labs/$id/',
      'DELETE',
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
