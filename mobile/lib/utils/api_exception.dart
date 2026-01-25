// lib/utils/api_exception.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int statusCode;
  final String body;

  /// سبب داخلي اختياري (مفيد للـ logging)
  final Object? cause;

  const ApiException(this.statusCode, this.body, {this.cause});

  /// -1 = خطأ شبكة/لا يوجد اتصال
  bool get isNetworkError => statusCode == -1;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $body';
}

class ApiExceptionUtils {
  static bool isNetworkException(Object e) {
    return e is SocketException || e is http.ClientException;
  }

  static ApiException network([Object? e]) {
    return ApiException(-1, 'NO_INTERNET', cause: e);
  }

  static ApiException fromResponse(http.Response r) {
    return ApiException(r.statusCode, r.body);
  }

  // ---------------------------------------------------------------------------
  // Extract message (single source of truth)
  // ---------------------------------------------------------------------------

  /// API موحّد:
  /// تقبل:
  /// - ApiException
  /// - http.Response
  /// - String (raw body)
  /// - decoded JSON (Map/List)
  ///
  /// وتعيد رسالة مناسبة للمستخدم.
  static String extractMessage(
    Object? e, {
    int? statusCode,
    String fallback = 'حدث خطأ غير متوقع.',
    int maxLen = 180,
  }) {
    // 1) Network (explicit)
    if (e is ApiException && e.isNetworkError) {
      return 'لا يوجد اتصال بالإنترنت.';
    }

    // 2) Network (native exceptions)
    if (e != null && isNetworkException(e)) {
      return 'لا يوجد اتصال بالإنترنت.';
    }

    // 3) ApiException
    if (e is ApiException) {
      return _extractFromBody(
        e.body,
        statusCode: e.statusCode,
        fallback: fallback,
        maxLen: maxLen,
      );
    }

    // 4) http.Response
    if (e is http.Response) {
      return _extractFromBody(
        e.body,
        statusCode: e.statusCode,
        fallback: fallback,
        maxLen: maxLen,
      );
    }

    // 5) decoded JSON passed directly
    if (e is Map || e is List) {
      return _extractFromDecoded(
        e as Object,
        statusCode: statusCode,
        fallback: fallback,
        maxLen: maxLen,
      );
    }

    // 6) raw string
    if (e is String) {
      return _extractFromBody(
        e,
        statusCode: statusCode,
        fallback: fallback,
        maxLen: maxLen,
      );
    }

    // 7) unknown
    return fallback;
  }

  /// Backward-compatible helper (إذا كنت مستخدمها في أماكن)
  /// ملاحظة: الأفضل تنتقل لـ extractMessage(...)
  static String extractMessageFromBody(String body, {int? statusCode}) {
    return _extractFromBody(
      body,
      statusCode: statusCode,
      fallback: _fallbackByStatus(statusCode) ?? 'حدث خطأ غير متوقع.',
      maxLen: 180,
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static String _extractFromBody(
    String body, {
    int? statusCode,
    required String fallback,
    required int maxLen,
  }) {
    final raw = body.toString().trim();
    if (raw.isEmpty) return _fallbackByStatus(statusCode) ?? fallback;

    try {
      final decoded = jsonDecode(raw);
      return _extractFromDecoded(
        decoded,
        statusCode: statusCode,
        fallback: fallback,
        maxLen: maxLen,
      );
    } catch (_) {
      // body ليس JSON
      final short = raw.length > maxLen ? '${raw.substring(0, maxLen)}…' : raw;
      return short;
    }
  }

  static String _extractFromDecoded(
    Object decoded, {
    int? statusCode,
    required String fallback,
    required int maxLen,
  }) {
    if (decoded is Map) {
      // شائع في DRF: {"detail": "..."}
      final detail = decoded['detail'];
      if (detail != null && detail.toString().trim().isNotEmpty) {
        return detail.toString();
      }

      // مثال: {"field":["msg"]} أو {"non_field_errors":["msg"]}
      for (final entry in decoded.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }

      return _fallbackByStatus(statusCode) ?? fallback;
    }

    if (decoded is List && decoded.isNotEmpty) {
      return decoded.first.toString();
    }

    return _fallbackByStatus(statusCode) ?? fallback;
  }

  static String? _fallbackByStatus(int? code) {
    if (code == null) return null;

    if (code == 401) return 'انتهت الجلسة. الرجاء تسجيل الدخول.';
    if (code == 403) return 'ليس لديك صلاحية لتنفيذ هذا الإجراء.';
    if (code == 404) return 'المورد غير موجود.';
    if (code >= 500) return 'مشكلة في الخادم. حاول لاحقاً.';

    // 4xx عامة
    if (code >= 400) return 'تعذّر تنفيذ الطلب. تحقق من المدخلات.';
    return 'HTTP $code';
  }
}
