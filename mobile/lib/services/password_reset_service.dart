// lib/services/password_reset_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/utils/constants.dart';
import '/utils/api_exception.dart';

class PasswordResetRequestResult {
  final bool success;
  final String? delivery; // "email" | "disabled" | "failed" | null
  final String? otp; // قد يعود في بيئة dev
  final int? expiresInMinutes;

  /// رسالة مفهومة عند الفشل (اختياري)
  final String? message;

  const PasswordResetRequestResult({
    required this.success,
    this.delivery,
    this.otp,
    this.expiresInMinutes,
    this.message,
  });
}

class PasswordResetService {
  Uri _uri(String endpoint) {
    final cleanBase =
        accountsBaseUrl.endsWith('/')
            ? accountsBaseUrl.substring(0, accountsBaseUrl.length - 1)
            : accountsBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<http.Response> _postJson(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final url = _uri(endpoint);

    try {
      return await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      // network / client exception
      if (ApiExceptionUtils.isNetworkException(e)) {
        throw ApiExceptionUtils.network(e);
      }
      throw ApiException(-1, e.toString(), cause: e);
    }
  }

  Future<PasswordResetRequestResult> requestOtp({required String email}) async {
    final response = await _postJson('password-reset/request/', {
      'email': email.trim(),
    });

    // نجاح: 2xx
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // حاول قراءة JSON
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final success = data['success'] == true;

        return PasswordResetRequestResult(
          success: success,
          delivery: data['delivery']?.toString(),
          otp: data['otp']?.toString(),
          expiresInMinutes:
              data['expires_in_minutes'] is int
                  ? data['expires_in_minutes'] as int
                  : int.tryParse(data['expires_in_minutes']?.toString() ?? ''),
        );
      } catch (_) {
        // لو لم يرجع JSON لأي سبب
        return const PasswordResetRequestResult(success: true);
      }
    }

    // فشل: 4xx/5xx -> رجّع نتيجة فشل مع رسالة مفهومة
    final msg = ApiExceptionUtils.extractMessageFromBody(
      response.body,
      statusCode: response.statusCode,
    );

    return PasswordResetRequestResult(
      success: false,
      delivery: null,
      otp: null,
      expiresInMinutes: null,
      message: msg,
    );
  }

  Future<bool> verifyOtp({required String email, required String code}) async {
    final response = await _postJson('password-reset/verify/', {
      'email': email.trim(),
      'code': code.trim(),
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['valid'] == true;
  }

  Future<bool> confirmNewPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await _postJson('password-reset/confirm/', {
      'email': email.trim(),
      'code': code.trim(),
      'new_password': newPassword,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true;
  }
}
