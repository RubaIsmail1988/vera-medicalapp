import 'dart:convert';
import 'auth_service.dart';
import '/utils/api_exception.dart';
import '../models/doctor_details.dart';
import '../models/patient_details.dart';

class DetailsService {
  final AuthService _authService = AuthService();

  // ================= Patient =================

  Future<void> createPatientDetails(PatientDetailsRequest request) async {
    final response = await _authService.authorizedRequest(
      "/patient-details/",
      "POST",
      body: request.toJson(),
    );

    if (response.statusCode == 201 || response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> getPatientDetails(int userId) async {
    final response = await _authService.authorizedRequest(
      "/patient-details/$userId/",
      "GET",
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> updatePatientDetails(PatientDetailsRequest request) async {
    final response = await _authService.authorizedRequest(
      "/patient-details/${request.userId}/",
      "PUT",
      body: request.toJson(),
    );

    if (response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> deletePatientDetails(int userId) async {
    final response = await _authService.authorizedRequest(
      "/patient-details/$userId/",
      "DELETE",
    );

    if (response.statusCode == 204 || response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  // ================= Doctor =================

  Future<void> createDoctorDetails(DoctorDetailsRequest request) async {
    final response = await _authService.authorizedRequest(
      "/doctor-details/",
      "POST",
      body: request.toJson(),
    );

    if (response.statusCode == 201 || response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  Future<Map<String, dynamic>> getDoctorDetails(int userId) async {
    final response = await _authService.authorizedRequest(
      "/doctor-details/$userId/",
      "GET",
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> updateDoctorDetails(DoctorDetailsRequest request) async {
    final response = await _authService.authorizedRequest(
      "/doctor-details/${request.userId}/",
      "PUT",
      body: request.toJson(),
    );

    if (response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }

  Future<void> deleteDoctorDetails(int userId) async {
    final response = await _authService.authorizedRequest(
      "/doctor-details/$userId/",
      "DELETE",
    );

    if (response.statusCode == 204 || response.statusCode == 200) return;

    throw ApiException(response.statusCode, response.body);
  }
}
