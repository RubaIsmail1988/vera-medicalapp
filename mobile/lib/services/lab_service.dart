import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/lab.dart';
import '/utils/api_exception.dart';
import 'auth_service.dart';

class LabService {
  final AuthService authService = AuthService();

  Future<List<Lab>> fetchLabs() async {
    final response = await authService.authorizedRequest('/labs/', 'GET');

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Lab.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

  Future<Lab> getLab(int id) async {
    final response = await authService.authorizedRequest('/labs/$id/', 'GET');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      return Lab.fromJson(data);
    }

    throw ApiExceptionUtils.fromResponse(response);
  }

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
