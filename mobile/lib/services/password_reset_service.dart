import 'dart:convert';
import 'package:http/http.dart' as http;

import '/utils/constants.dart';

class PasswordResetService {
  Uri _uri(String endpoint) {
    // accountsBaseUrl مثال: http://127.0.0.1:8000/api/accounts
    final cleanBase =
        accountsBaseUrl.endsWith('/')
            ? accountsBaseUrl.substring(0, accountsBaseUrl.length - 1)
            : accountsBaseUrl;

    // endpoint مثال: password-reset/request/ أو /password-reset/request/
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  Future<bool> requestOtp({required String email}) async {
    final url = _uri('password-reset/request/');

    final response = await http.post(
      url,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'email': email}),
    );

    // API يرجّع نجاح حتى لو البريد غير موجود (سلوك أمني صحيح)
    return response.statusCode >= 200 && response.statusCode < 300;
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
