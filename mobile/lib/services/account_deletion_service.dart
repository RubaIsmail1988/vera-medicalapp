import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AccountDeletionService {
  final AuthService authService = AuthService();

  /// إنشاء طلب حذف حساب
  /// يستخدم endpoint:
  /// POST /api/accounts/account-deletion/request/
  Future<bool> createDeletionRequest({String? reason}) async {
    final body =
        reason != null && reason.trim().isNotEmpty
            ? {'reason': reason.trim()}
            : <String, dynamic>{};

    final response = await authService.authorizedRequest(
      '/account-deletion/request/',
      'POST',
      body: body,
    );

    return response.statusCode == 201 || response.statusCode == 200;
  }

  /// جلب آخر طلبات حذف الحساب للمستخدم الحالي (مثلاً آخر 5)
  /// endpoint:
  /// GET /api/accounts/account-deletion/my-requests/

  Future<List<Map<String, dynamic>>> fetchMyDeletionRequests() async {
    final http.Response response = await authService.authorizedRequest(
      '/account-deletion/my-requests/',
      'GET',
    );

    if (response.statusCode != 200) {
      return <Map<String, dynamic>>[];
    }

    final dynamic body = jsonDecode(response.body);

    if (body is List) {
      return body.cast<Map<String, dynamic>>();
    } else if (body is Map && body['results'] is List) {
      return (body['results'] as List).cast<Map<String, dynamic>>();
    }

    return <Map<String, dynamic>>[];
  }
}
