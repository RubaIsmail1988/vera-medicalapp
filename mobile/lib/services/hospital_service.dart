import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../models/hospital.dart';

class HospitalService {
  final AuthService _authService = AuthService();

  // جلب قائمة كل المشافي
  Future<List<Hospital>> fetchHospitals() async {
    final http.Response response = await _authService.authorizedRequest(
      "/hospitals/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Hospital.fromJson(e)).toList();
    }

    throw Exception(
      "Failed to load hospitals: ${response.statusCode} ${response.body}",
    );
  }

  // جلب مشفى واحد
  Future<Hospital> getHospital(int id) async {
    final http.Response response = await _authService.authorizedRequest(
      "/hospitals/$id/",
      "GET",
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Hospital.fromJson(data);
    }

    throw Exception(
      "Failed to load labs: ${response.statusCode} ${response.body}",
    );
  }

  // إنشاء مشفى جديد
  Future<http.Response> createHospital(Hospital hospital) async {
    return _authService.authorizedRequest(
      "/hospitals/",
      "POST",
      body: hospital.toJson(),
    );
  }

  // تحديث مشفى موجود
  Future<http.Response> updateHospital(Hospital hospital) async {
    if (hospital.id == null) {
      throw Exception("Hospital ID is required for update");
    }

    return _authService.authorizedRequest(
      "/hospitals/${hospital.id}/",
      "PUT", // يمكن استخدام PATCH لو أردت لاحقاً
      body: hospital.toJson(),
    );
  }

  // حذف مشفى
  Future<bool> deleteHospital(int id) async {
    final http.Response response = await _authService.authorizedRequest(
      "/hospitals/$id/",
      "DELETE",
    );
    return response.statusCode == 204 || response.statusCode == 200;
  }
}
