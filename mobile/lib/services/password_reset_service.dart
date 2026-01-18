import 'dart:convert';
import 'package:http/http.dart' as http;

import '/utils/constants.dart';

class PasswordResetRequestResult {
  final bool success;
  final String? delivery; // "email" | "disabled" | "failed" | null
  final String? otp;
  final int? expiresInMinutes;

  const PasswordResetRequestResult({
    required this.success,
    this.delivery,
    this.otp,
    this.expiresInMinutes,
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

  Future<PasswordResetRequestResult> requestOtp({required String email}) async {
    final url = _uri('password-reset/request/');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const PasswordResetRequestResult(success: false);
    }

    // حاول قراءة JSON (قد يرجع فقط {"success": true, "delivery": "..."} إلخ)
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
                : null,
      );
    } catch (_) {
      // لو لم يرجع JSON لأي سبب
      return const PasswordResetRequestResult(success: true);
    }
  }

  Future<bool> verifyOtp({required String email, required String code}) async {
    final url = _uri('password-reset/verify/');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email, 'code': code}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['valid'] == true;
  }

  Future<bool> confirmNewPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final url = _uri('password-reset/confirm/');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true;
  }
}
