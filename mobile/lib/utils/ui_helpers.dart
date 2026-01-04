import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, warning, error }

/// Root messenger key لتفادي مشاكل context + go_router
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// إظهار SnackBar موحّد في كل التطبيق.
/// - يعتمد على rootScaffoldMessengerKey أولاً (الأكثر أماناً)
/// - يستخدم context فقط إن أردت ألوان الثيم (اختياري)
void showAppSnackBar(
  BuildContext? context,
  String message, {
  AppSnackBarType type = AppSnackBarType.info,
  Duration duration = const Duration(seconds: 3),
  SnackBarAction? action,
  bool clearPrevious = true,
}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  if (clearPrevious) {
    messenger.clearSnackBars();
  }

  final cs = context != null ? Theme.of(context).colorScheme : null;

  Color background;
  Color foreground;
  IconData icon;

  switch (type) {
    case AppSnackBarType.success:
      background = Colors.green.withValues(alpha: 0.18);
      foreground = Colors.greenAccent;
      icon = Icons.check_circle_outline;
      break;
    case AppSnackBarType.warning:
      background = Colors.orange.withValues(alpha: 0.18);
      foreground = Colors.orangeAccent;
      icon = Icons.warning_amber_rounded;
      break;
    case AppSnackBarType.error:
      background = Colors.red.withValues(alpha: 0.18);
      foreground = Colors.redAccent;
      icon = Icons.error_outline;
      break;
    case AppSnackBarType.info:
      background = (cs?.surface ?? const Color(0xFF111316)).withValues(
        alpha: 0.90,
      );
      foreground = (cs?.onSurface ?? Colors.white).withValues(alpha: 0.92);
      icon = Icons.info_outline;
      break;
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: background,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      action: action,
      content: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

void showAppErrorSnackBar(BuildContext? context, String message) {
  showAppSnackBar(context, message, type: AppSnackBarType.error);
}

void showAppSuccessSnackBar(BuildContext? context, String message) {
  showAppSnackBar(context, message, type: AppSnackBarType.success);
}

/// Dialog موحّد للتأكيد (حذف/رفض/تعطيل...)
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );

  return result == true;
}

// ---------------------------------------------------------------------------
// API / Networking helpers
// ---------------------------------------------------------------------------

/// يحاول استخراج رسالة خطأ مفيدة من payload قادم من الـ API.
/// يدعم الأنماط الشائعة:
/// - {"detail": "..."}
/// - {"detail": ["..."] }
/// - {"field": ["msg1", "msg2"], "field2": ["msg"] }
String extractApiErrorMessage(
  Object? data, {
  String fallback = 'تعذّر تنفيذ العملية. يرجى التحقق من البيانات.',
}) {
  if (data == null) return fallback;

  if (data is String) {
    final trimmed = data.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  if (data is List) {
    if (data.isEmpty) return fallback;
    final first = data.first;
    if (first is String && first.trim().isNotEmpty) return first.trim();
    return first.toString();
  }

  if (data is Map) {
    if (data.containsKey('detail')) {
      final detail = data['detail'];
      final msg = extractApiErrorMessage(detail, fallback: fallback);
      if (msg.trim().isNotEmpty) return msg;
    }

    if (data.containsKey('non_field_errors')) {
      final nfe = data['non_field_errors'];
      final msg = extractApiErrorMessage(nfe, fallback: fallback);
      if (msg.trim().isNotEmpty) return msg;
    }

    for (final entry in data.entries) {
      final value = entry.value;

      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
        return first.toString();
      }

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return fallback;
  }

  final s = data.toString().trim();
  return s.isEmpty ? fallback : s;
}

String mapHttpErrorToArabicMessage({required int? statusCode, Object? data}) {
  if (statusCode == null) {
    return 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.';
  }

  if (statusCode == 401) {
    return 'انتهت الجلسة، يرجى تسجيل الدخول مجددًا.';
  }

  if (statusCode == 403) {
    return 'لا تملك صلاحية تنفيذ هذا الإجراء.';
  }

  if (statusCode == 404) {
    return 'العنصر غير موجود.';
  }

  if (statusCode == 400) {
    return extractApiErrorMessage(data);
  }

  if (statusCode >= 500) {
    return 'حدث خطأ غير متوقع. حاول مرة أخرى لاحقًا.';
  }

  return extractApiErrorMessage(data, fallback: 'تعذّر تنفيذ العملية.');
}

void showApiErrorSnackBar(
  BuildContext? context, {
  required int? statusCode,
  Object? data,
}) {
  final message = mapHttpErrorToArabicMessage(
    statusCode: statusCode,
    data: data,
  );
  showAppErrorSnackBar(context, message);
}
