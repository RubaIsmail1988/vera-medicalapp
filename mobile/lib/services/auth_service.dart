import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/register_request.dart';
import '/utils/constants.dart';

class AuthService {
  // ---------------- حفظ واسترجاع التوكنات ----------------

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("access_token", access);
    await prefs.setString("refresh_token", refresh);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("access_token");
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("refresh_token");
  }

  /// حفظ معلومات المستخدم الأساسية (للـ B-1)
  Future<void> saveUserInfo(String role, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_role", role);
    await prefs.setInt("user_id", userId);
  }

  // ---------------- أدوات بناء الروابط ----------------

  Uri buildAccountsUri(String endpoint) {
    // endpoint قد يأتي "/users/" أو "users/"
    final cleanBase =
        accountsBaseUrl.endsWith('/')
            ? accountsBaseUrl.substring(0, accountsBaseUrl.length - 1)
            : accountsBaseUrl;

    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    return Uri.parse('$cleanBase$cleanEndpoint');
  }

  // ---------------- تسجيل المستخدم ----------------

  Future<http.Response> register(RegisterRequest request) async {
    // endpoint: /api/accounts/register/<role>/
    final url = buildAccountsUri('/register/${request.role}/');

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode(request.toJson()),
    );

    return response;
  }

  // ---------------- تسجيل الدخول ----------------

  Future<Map<String, dynamic>?> login(String email, String password) async {
    final response = await http.post(
      buildAccountsUri('/login/'),
      headers: {'Accept': 'application/json'},
      body: {'email': email, 'password': password},
    );

    // 1) حالة النجاح: مستخدم مفعّل (backend يعيد 200)
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final role = data['role'];
      final userId = data['user_id'];
      final isActive = data['is_active'] ?? data['isActivated'] ?? true;

      final access = data['access'] ?? data['access_token'] ?? data['token'];
      final refresh = data['refresh'];

      //  حفظ access دائمًا إذا كان موجودًا، وحفظ refresh فقط إذا كان موجودًا
      final prefs = await SharedPreferences.getInstance();

      if (access is String && access.isNotEmpty) {
        await prefs.setString("access_token", access);
      }

      if (refresh is String && refresh.isNotEmpty) {
        await prefs.setString("refresh_token", refresh);
      }

      if (role is String && userId is int) {
        await saveUserInfo(role, userId);
      }

      return {
        'role': role,
        'user_id': userId,
        'is_active': isActive,
        'access_token': access,
      };
    }

    // 2) غير 200 → إما not_active أو invalid
    try {
      final body = jsonDecode(response.body);

      final codeValue = body['code'];
      bool isNotActive = false;

      if (codeValue is String && codeValue == 'not_active') {
        isNotActive = true;
      } else if (codeValue is List &&
          codeValue.isNotEmpty &&
          codeValue.first == 'not_active') {
        isNotActive = true;
      }

      if (isNotActive) {
        String? role;

        final roleValue = body['role'];
        if (roleValue is String) {
          role = roleValue;
        } else if (roleValue is List && roleValue.isNotEmpty) {
          role = roleValue.first.toString();
        }

        return {'error': 'not_active', if (role != null) 'role': role};
      }

      // fallback: اكتشاف من detail
      final detailValue = body['detail'];
      if (detailValue != null) {
        String detailText;
        if (detailValue is String) {
          detailText = detailValue;
        } else if (detailValue is List && detailValue.isNotEmpty) {
          detailText = detailValue.first.toString();
        } else {
          detailText = '';
        }

        final lower = detailText.toLowerCase();
        if (lower.contains('not activated') || lower.contains('not_active')) {
          return {'error': 'not_active'};
        }
      }

      // invalid
      return null;
    } catch (_) {
      return null;
    }
  }

  //Future<void> saveAuthData(String token, String role, bool isActivated) async {
  //  final prefs = await SharedPreferences.getInstance();
  //  await prefs.setString('access_token', token);
  // await prefs.setString('user_role', role);
  // await prefs.setBool('is_activated', isActivated);
  // }

  // ---------------- تحديث التوكن ----------------

  Future<void> refreshToken() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return;

    final response = await http.post(
      buildAccountsUri('/token/refresh/'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: jsonEncode({"refresh": refresh}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final access = data["access"];
      if (access is String) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("access_token", access);
      }
    }
  }

  // ---------------- طلبات مصادَقة موحّدة ----------------

  Future<http.Response> authorizedRequest(
    String endpoint,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> send(String token) async {
      final url = buildAccountsUri(endpoint);

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

      switch (method.toUpperCase()) {
        case "GET":
          return http.get(url, headers: headers);
        case "POST":
          return http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "PUT":
          return http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "PATCH":
          return http.patch(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
        case "DELETE":
          return http.delete(url, headers: headers);
        default:
          throw Exception("Invalid HTTP method");
      }
    }

    String? token = await getAccessToken();

    // إذا لا يوجد توكن أصلًا → جرّب refresh
    if (token == null) {
      await refreshToken();
      token = await getAccessToken();
    }

    if (token == null) {
      return http.Response('Unauthorized', 401);
    }

    final first = await send(token);

    if (first.statusCode == 401) {
      await refreshToken();
      final newToken = await getAccessToken();
      if (newToken == null) {
        return first;
      }
      return send(newToken);
    }

    return first;
  }

  /// جلب بيانات المستخدم الحالي من /me/ وتخزينها محلياً
  Future<Map<String, dynamic>?> fetchAndStoreCurrentUser() async {
    final response = await authorizedRequest("/me/", "GET");

    if (response.statusCode != 200) {
      return null;
    }

    final Map<String, dynamic> data = jsonDecode(response.body);

    final prefs = await SharedPreferences.getInstance();

    final String username = data["username"]?.toString() ?? "";
    final String email = data["email"]?.toString() ?? "";
    final String role = data["role"]?.toString() ?? "";
    final bool isActive = data["is_active"] == true;

    await prefs.setString("currentUserName", username);
    await prefs.setString("currentUserEmail", email);
    await prefs.setString("currentUserRole", role);
    await prefs.setBool("user_is_active", isActive);

    final dynamic rawId = data["id"];
    final int userId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "") ?? 0;
    await prefs.setInt("currentUserId", userId);

    return data;
  }

  // ---------------- تسجيل الخروج ----------------

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('is_activated');

    await prefs.remove("currentUserName");
    await prefs.remove("currentUserEmail");
    await prefs.remove("currentUserRole");
    await prefs.remove("user_is_active");
    await prefs.remove("currentUserId");
  }
}
