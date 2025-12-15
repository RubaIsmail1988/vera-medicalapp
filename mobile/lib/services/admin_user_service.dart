import 'dart:convert';

import 'auth_service.dart';

class AdminUserService {
  final AuthService authService = AuthService();

  /// جلب جميع المستخدمين
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final response = await authService.authorizedRequest("/users/", "GET");

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to load users: ${response.statusCode}');
  }

  /// جلب المرضى فقط
  Future<List<Map<String, dynamic>>> fetchPatients() async {
    final response = await authService.authorizedRequest("/patients/", "GET");

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to load patients: ${response.statusCode}');
  }

  /// جلب الأطباء فقط
  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final response = await authService.authorizedRequest("/doctors/", "GET");

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to load doctors: ${response.statusCode}');
  }

  /// تعطيل مستخدم
  Future<bool> deactivateUser(int userId) async {
    final response = await authService.authorizedRequest(
      "/users/$userId/deactivate/",
      "POST",
    );
    return response.statusCode == 200;
  }

  /// تفعيل مستخدم
  Future<bool> activateUser(int userId) async {
    final response = await authService.authorizedRequest(
      "/users/$userId/activate/",
      "POST",
    );
    return response.statusCode == 200;
  }

  /// جلب جميع طلبات حذف الحساب (للأدمن)
  Future<List<Map<String, dynamic>>> fetchDeletionRequests() async {
    final response = await authService.authorizedRequest(
      "/account-deletion/requests/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception('Failed to load deletion requests: ${response.statusCode}');
  }

  /// الموافقة على طلب حذف حساب
  Future<bool> approveDeletionRequest(
    int requestId, {
    String? adminNote,
  }) async {
    final response = await authService.authorizedRequest(
      "/account-deletion/requests/$requestId/approve/",
      "POST",
      body:
          adminNote != null && adminNote.trim().isNotEmpty
              ? {"admin_note": adminNote.trim()}
              : {},
    );

    return response.statusCode == 200;
  }

  /// رفض طلب حذف حساب
  Future<bool> rejectDeletionRequest(int requestId, {String? adminNote}) async {
    final response = await authService.authorizedRequest(
      "/account-deletion/requests/$requestId/reject/",
      "POST",
      body:
          adminNote != null && adminNote.trim().isNotEmpty
              ? {"admin_note": adminNote.trim()}
              : {},
    );

    return response.statusCode == 200;
  }
}
