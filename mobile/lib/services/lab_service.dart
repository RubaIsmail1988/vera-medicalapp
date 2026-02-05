import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/lab.dart';
import '/utils/api_exception.dart';
import '/utils/constants.dart';
import 'auth_service.dart';

class LabService {
  final AuthService authService = AuthService();

  // --------------------------------------------------------------------------
  // URL helpers
  // --------------------------------------------------------------------------

  Uri _buildAccountsUri(String endpoint) {
    final cleanBase =
        accountsBaseUrl.endsWith('/')
            ? accountsBaseUrl.substring(0, accountsBaseUrl.length - 1)
            : accountsBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  // --------------------------------------------------------------------------
  // Public (no auth) — used in user/public screens (and before login)
  // --------------------------------------------------------------------------

  Future<List<Lab>> fetchLabs() async {
    final url = _buildAccountsUri('/labs/');

    final response = await http.get(
      url,
      headers: const {"Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);

      // API may return List OR {results:[...]}
      final List<dynamic> items =
          (decoded is Map && decoded["results"] is List)
              ? (decoded["results"] as List<dynamic>)
              : (decoded is List ? decoded : <dynamic>[]);

      return items
          .whereType<Map>()
          .map((e) => Lab.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

  Future<Lab> getLab(int id) async {
    final url = _buildAccountsUri('/labs/$id/');

    final response = await http.get(
      url,
      headers: const {"Accept": "application/json"},
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Lab.fromJson(data);
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

  // --------------------------------------------------------------------------
  // Admin (authorized) — keep as-is for CRUD
  // --------------------------------------------------------------------------

  // نتركها Response لأن الشاشات غالباً تفحص statusCode
  Future<http.Response> createLab(Lab lab) {
    return authService.authorizedRequest('/labs/', 'POST', body: lab.toJson());
  }

  Future<http.Response> updateLab(Lab lab) {
    final labId = lab.id;
    if (labId == null) {
      throw const ApiException(400, 'Lab ID is required for update');
    }

    return authService.authorizedRequest(
      '/labs/$labId/',
      'PUT',
      body: lab.toJson(),
    );
  }

  // حالياً نتركها bool حتى لا نكسر الشاشات (مثل ما عملنا بالمشفى سابقاً)
  Future<bool> deleteLab(int id) async {
    final response = await authService.authorizedRequest(
      '/labs/$id/',
      'DELETE',
    );

    if (response.statusCode == 200 || response.statusCode == 204) return true;

    // لاحقاً: نحولها إلى throw ApiExceptionUtils.fromResponse(response);
    return false;
  }
}
