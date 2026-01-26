import 'dart:convert';
import '/models/hospital.dart';
import '/utils/api_exception.dart';
import 'auth_service.dart';

class HospitalService {
  final AuthService authService = AuthService();

  Future<List<Hospital>> fetchHospitals() async {
    try {
      final response = await authService.authorizedRequest(
        '/hospitals/',
        'GET',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((e) => Hospital.fromJson(e as Map<String, dynamic>))
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
      final response = await authService.authorizedRequest(
        '/hospitals/$id/',
        'GET',
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
