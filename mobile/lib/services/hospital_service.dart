import 'dart:convert';

import 'package:http/http.dart' as http;

import '/models/hospital.dart';
import '/utils/api_exception.dart';
import '/utils/constants.dart';
import 'auth_service.dart';

class HospitalService {
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

  Future<List<Hospital>> fetchHospitals() async {
    try {
      final url = _buildAccountsUri('/hospitals/');

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
            .map((e) => Hospital.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }
  }

  Future<Hospital> getHospital(int id) async {
    try {
      final url = _buildAccountsUri('/hospitals/$id/');

      final response = await http.get(
        url,
        headers: const {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return Hospital.fromJson(data);
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }
  }

  // --------------------------------------------------------------------------
  // Admin (authorized) — keep as-is for CRUD
  // --------------------------------------------------------------------------

  Future<Hospital> createHospital(Hospital hospital) async {
    try {
      final response = await authService.authorizedRequest(
        '/hospitals/',
        'POST',
        body: hospital.toJson(),
      );

      // بعض الـ backends ترجع 201 مع body، وبعضها 201 بدون body
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          // إذا ما في body نرجّع الكائن المرسل (حل آمن مؤقتاً)
          return hospital;
        }
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return Hospital.fromJson(data);
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }
  }

  Future<Hospital> updateHospital(Hospital hospital) async {
    final hospitalId = hospital.id;
    if (hospitalId == null) {
      throw const ApiException(400, 'Hospital ID is required for update');
    }

    try {
      final response = await authService.authorizedRequest(
        '/hospitals/$hospitalId/',
        'PUT',
        body: hospital.toJson(),
      );

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          return hospital;
        }
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return Hospital.fromJson(data);
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }
  }

  Future<void> deleteHospital(int id) async {
    try {
      final response = await authService.authorizedRequest(
        '/hospitals/$id/',
        'DELETE',
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      rethrow;
    }
  }
}
