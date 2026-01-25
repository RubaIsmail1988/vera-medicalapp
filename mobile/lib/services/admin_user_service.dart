import 'dart:convert';

import '/utils/api_exception.dart';
import 'auth_service.dart';

class AdminUserService {
  final AuthService authService = AuthService();

  // ----------------------------
  // Helpers
  // ----------------------------

  List<Map<String, dynamic>> _decodeList(String body) {
    final dynamic data = jsonDecode(body);

    // أغلب endpoints هنا ترجع List مباشرة
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }

    // احتياط لو رجع Pagination
    if (data is Map && data['results'] is List) {
      return (data['results'] as List).cast<Map<String, dynamic>>();
    }

    return <Map<String, dynamic>>[];
  }

  // ----------------------------
  // Users
  // ----------------------------

  /// جلب جميع المستخدمين
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final response = await authService.authorizedRequestOrThrow(
      "/users/",
      "GET",
    );
    return _decodeList(response.body);
  }

  /// جلب المرضى فقط
  Future<List<Map<String, dynamic>>> fetchPatients() async {
    final response = await authService.authorizedRequestOrThrow(
      "/patients/",
      "GET",
    );
    return _decodeList(response.body);
  }

  /// جلب الأطباء فقط
  Future<List<Map<String, dynamic>>> fetchDoctors() async {
    final response = await authService.authorizedRequestOrThrow(
      "/doctors/",
      "GET",
    );
    return _decodeList(response.body);
  }

  /// تعطيل مستخدم
  Future<bool> deactivateUser(int userId) async {
    try {
      await authService.authorizedRequestOrThrow(
        "/users/$userId/deactivate/",
        "POST",
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// تفعيل مستخدم
  Future<bool> activateUser(int userId) async {
    try {
      await authService.authorizedRequestOrThrow(
        "/users/$userId/activate/",
        "POST",
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  // ----------------------------
  // Account deletion requests (Admin)
  // ----------------------------

  /// جلب جميع طلبات حذف الحساب (للأدمن)
  Future<List<Map<String, dynamic>>> fetchDeletionRequests() async {
    final response = await authService.authorizedRequestOrThrow(
      "/account-deletion/requests/",
      "GET",
    );
    return _decodeList(response.body);
  }

  /// الموافقة على طلب حذف حساب
  Future<bool> approveDeletionRequest(
    int requestId, {
    String? adminNote,
  }) async {
    final Map<String, dynamic> body =
        adminNote != null && adminNote.trim().isNotEmpty
            ? {"admin_note": adminNote.trim()}
            : <String, dynamic>{};

    try {
      await authService.authorizedRequestOrThrow(
        "/account-deletion/requests/$requestId/approve/",
        "POST",
        body: body,
      );
      return true;
    } on ApiException {
      return false;
    }
  }

  /// رفض طلب حذف حساب
  Future<bool> rejectDeletionRequest(int requestId, {String? adminNote}) async {
    final Map<String, dynamic> body =
        adminNote != null && adminNote.trim().isNotEmpty
            ? {"admin_note": adminNote.trim()}
            : <String, dynamic>{};

    try {
      await authService.authorizedRequestOrThrow(
        "/account-deletion/requests/$requestId/reject/",
        "POST",
        body: body,
      );
      return true;
    } on ApiException {
      return false;
    }
  }
}
