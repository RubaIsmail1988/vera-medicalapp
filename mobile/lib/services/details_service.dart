import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/doctor_details.dart';
import '../models/patient_details.dart';

class DetailsService {
  final AuthService _authService = AuthService();

  // ---------------- Patient ----------------
  Future<http.Response> createPatientDetails(
    PatientDetailsRequest request,
  ) async {
    return await _authService.authorizedRequest(
      "/patient-details/",
      "POST",
      body: request.toJson(),
    );
  }

  Future<http.Response> getPatientDetails(int userId) async {
    return await _authService.authorizedRequest(
      "/patient-details/$userId/",
      "GET",
    );
  }

  Future<http.Response> updatePatientDetails(
    PatientDetailsRequest request,
  ) async {
    return await _authService.authorizedRequest(
      "/patient-details/${request.userId}/",
      "PUT",
      body: request.toJson(),
    );
  }

  Future<http.Response> deletePatientDetails(int userId) async {
    return await _authService.authorizedRequest(
      "/patient-details/$userId/",
      "DELETE",
    );
  }

  // ---------------- Doctor ----------------
  Future<http.Response> createDoctorDetails(
    DoctorDetailsRequest request,
  ) async {
    return await _authService.authorizedRequest(
      "/doctor-details/",
      "POST",
      body: request.toJson(),
    );
  }

  Future<http.Response> getDoctorDetails(int userId) async {
    return await _authService.authorizedRequest(
      "/doctor-details/$userId/",
      "GET",
    );
  }

  Future<http.Response> updateDoctorDetails(
    DoctorDetailsRequest request,
  ) async {
    return await _authService.authorizedRequest(
      "/doctor-details/${request.userId}/",
      "PUT",
      body: request.toJson(),
    );
  }

  Future<http.Response> deleteDoctorDetails(int userId) async {
    return await _authService.authorizedRequest(
      "/doctor-details/$userId/",
      "DELETE",
    );
  }
}
