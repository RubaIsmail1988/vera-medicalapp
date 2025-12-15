import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../models/lab.dart';

class LabService {
  final AuthService _authService = AuthService();

  // جلب جميع المخابر
  Future<List<Lab>> fetchLabs() async {
    final response = await _authService.authorizedRequest("/labs/", "GET");

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Lab.fromJson(e)).toList();
    }

    throw Exception("Failed to load labs: ${response.statusCode}");
  }

  // جلب مخبر واحد
  Future<Lab> getLab(int id) async {
    final response = await _authService.authorizedRequest("/labs/$id/", "GET");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return Lab.fromJson(data);
    }

    throw Exception(
      "Failed to load labs: ${response.statusCode} ${response.body}",
    );
  }

  // إنشاء مخبر
  Future<http.Response> createLab(Lab lab) async {
    return _authService.authorizedRequest("/labs/", "POST", body: lab.toJson());
  }

  // تحديث مخبر
  Future<http.Response> updateLab(Lab lab) async {
    if (lab.id == null) {
      throw Exception("Lab ID is required for update");
    }

    return _authService.authorizedRequest(
      "/labs/${lab.id}/",
      "PUT",
      body: lab.toJson(),
    );
  }

  // حذف مخبر
  Future<bool> deleteLab(int id) async {
    final response = await _authService.authorizedRequest(
      "/labs/$id/",
      "DELETE",
    );

    return response.statusCode == 200 || response.statusCode == 204;
  }
}
