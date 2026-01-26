import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_exception.dart';
import 'auth_service.dart';

class AccountDeletionService {
  final AuthService authService = AuthService();

  Future<bool> createDeletionRequest({String? reason}) async {
    final body =
        reason != null && reason.trim().isNotEmpty
            ? {'reason': reason.trim()}
            : <String, dynamic>{};

    try {
      final response = await authService.authorizedRequest(
        '/account-deletion/request/',
        'POST',
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }

      throw ApiExceptionUtils.fromResponse(response);
    } catch (e) {
      // authorizedRequest ممكن يرمي SocketException/ClientException
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      // إذا كان أصلاً ApiException خلّيه يطلع كما هو
      if (e is ApiException) rethrow;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyDeletionRequests() async {
    try {
      final http.Response response = await authService.authorizedRequest(
        '/account-deletion/my-requests/',
        'GET',
      );

      if (response.statusCode != 200) {
        throw ApiExceptionUtils.fromResponse(response);
      }

      final dynamic body = jsonDecode(response.body);

      if (body is List) {
        return body.cast<Map<String, dynamic>>();
      } else if (body is Map && body['results'] is List) {
        return (body['results'] as List).cast<Map<String, dynamic>>();
      }

      // استجابة غير متوقعة (نعتبرها خطأ API منطقي)
      throw const ApiException(200, 'Unexpected response shape');
    } catch (e) {
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      if (e is ApiException) rethrow;
      rethrow;
    }
  }
}
