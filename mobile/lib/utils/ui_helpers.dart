import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '/utils/api_exception.dart';

enum AppSnackBarType { info, success, warning, error }

/// Root messenger key لتفادي مشاكل context + go_router
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ---------------------------------------------------------------------------
// SnackBar (موحّد)
// ---------------------------------------------------------------------------

/// إظهار SnackBar موحّد في كل التطبيق.
/// ملاحظة سلوكية:
/// - لا تستخدم SnackBar لأخطاء تحميل البيانات (Fetch) داخل الشاشات.
/// - استخدمها فقط لأخطاء "العمليات" (Action) مثل حفظ/حذف/حجز.
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

  final trimmed = message.trim();
  if (trimmed.isEmpty) return;

  if (clearPrevious) {
    messenger.clearSnackBars();
  }

  final cs = context != null ? Theme.of(context).colorScheme : null;

  Color background;
  Color foreground;
  IconData icon;

  // نعتمد ColorScheme قدر الإمكان بدل Colors مباشرة
  switch (type) {
    case AppSnackBarType.success:
      background = (cs?.primaryContainer ?? const Color(0xFF0E3B2C)).withValues(
        alpha: 0.92,
      );
      foreground = (cs?.onPrimaryContainer ?? Colors.white).withValues(
        alpha: 0.95,
      );
      icon = Icons.check_circle_outline;
      break;

    case AppSnackBarType.warning:
      background = (cs?.secondaryContainer ?? const Color(0xFF3B2A0E))
          .withValues(alpha: 0.92);
      foreground = (cs?.onSecondaryContainer ?? Colors.white).withValues(
        alpha: 0.95,
      );
      icon = Icons.warning_amber_rounded;
      break;

    case AppSnackBarType.error:
      background = (cs?.errorContainer ?? const Color(0xFF3B1111)).withValues(
        alpha: 0.92,
      );
      foreground = (cs?.onErrorContainer ?? Colors.white).withValues(
        alpha: 0.95,
      );
      icon = Icons.error_outline;
      break;

    case AppSnackBarType.info:
      background = (cs?.surface ?? const Color(0xFF111316)).withValues(
        alpha: 0.92,
      );
      foreground = (cs?.onSurface ?? Colors.white).withValues(alpha: 0.95);
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
              trimmed,
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

// ---------------------------------------------------------------------------
// Dialog (موحّد)
// ---------------------------------------------------------------------------

/// Dialog موحّد للتأكيد (حذف/رفض/تعطيل...)
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'تأكيد',
  String cancelText = 'إلغاء',
  bool danger = false,
}) async {
  final cs = Theme.of(context).colorScheme;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, textAlign: TextAlign.right),
          content: Text(message, textAlign: TextAlign.right),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelText),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  danger
                      ? FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      )
                      : null,
              child: Text(confirmText),
            ),
          ],
        ),
      );
    },
  );

  return result == true;
}

// ---------------------------------------------------------------------------
// API / Networking helpers
// ---------------------------------------------------------------------------

/// يحاول استخراج رسالة خطأ مفيدة من payload قادم من الـ API.
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

/// تحويل Exceptions الشائعة (خصوصًا عند انقطاع الإنترنت) إلى رسالة مفهومة.
/// هذه تمنع تسريب: ClientException / uri / stacktrace للمستخدم.
String mapExceptionToArabicMessage(
  Object error, {
  String fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.',
}) {
  // Timeout
  if (error is TimeoutException) {
    return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
  }

  // Socket (offline / DNS / refused)
  if (error is SocketException) {
    return 'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
  }

  // TLS/SSL/Handshake
  if (error is HandshakeException) {
    return 'تعذّر إنشاء اتصال آمن. حاول مرة أخرى لاحقًا.';
  }

  // HttpException (من dart:io)
  if (error is HttpException) {
    return 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.';
  }

  // بعض الأخطاء تأتي كنص
  final text = error.toString();

  // ClientException / connection closed / failed host lookup ... الخ
  final lower = text.toLowerCase();
  final looksOffline =
      lower.contains('clientexception') ||
      lower.contains('connection closed') ||
      lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection refused') ||
      lower.contains('no address associated') ||
      lower.contains('socket') ||
      lower.contains('os error');

  if (looksOffline) {
    return 'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
  }

  return fallback;
}

// ---------------------------------------------------------------------------
// Public "contracts" for UI behavior
// ---------------------------------------------------------------------------

/// أخطاء العمليات (Action): حفظ/حذف/حجز/إرسال.
/// هنا فقط نستخدم SnackBar.
void showActionErrorSnackBar(
  BuildContext? context, {
  int? statusCode,
  Object? data,
  Object? exception,
  String fallback = 'تعذّر تنفيذ العملية.',
}) {
  final message = () {
    // NEW: handle ApiException directly
    if (exception is ApiException) {
      return mapHttpErrorToArabicMessage(
        statusCode: exception.statusCode,
        data: exception.body,
      );
    }

    if (statusCode != null) {
      return mapHttpErrorToArabicMessage(statusCode: statusCode, data: data);
    }
    if (exception != null) {
      return mapExceptionToArabicMessage(exception, fallback: fallback);
    }
    if (data != null) {
      return extractApiErrorMessage(data, fallback: fallback);
    }
    return fallback;
  }();

  showAppErrorSnackBar(context, message);
}

/// Widget موحّد لأخطاء تحميل البيانات (Fetch).
/// ملاحظة: هنا لا يوجد SnackBar نهائيًا.
class AppInlineErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppInlineErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.wifi_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: cs.onSurface.withValues(alpha: 0.75)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  height: 1.3,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper سريع لاستخدامه في الشاشات عند Catch exception في Fetch:
/// يرجع (title/message) جاهزين للعرض داخل الصفحة.
({String title, String message, IconData icon}) mapFetchExceptionToInlineState(
  Object error,
) {
  final msg = mapExceptionToArabicMessage(
    error,
    fallback: 'تعذّر تحميل البيانات. حاول مرة أخرى.',
  );

  // لو الرسالة هي Offline نستخدم أيقونة wifi_off
  if (msg.contains('لا يوجد اتصال')) {
    return (
      title: 'لا يوجد اتصال بالإنترنت',
      message: 'تحقق من الاتصال وحاول مرة أخرى.',
      icon: Icons.wifi_off_rounded,
    );
  }

  if (msg.contains('انتهت مهلة')) {
    return (
      title: 'انتهت مهلة الاتصال',
      message: 'حاول مرة أخرى.',
      icon: Icons.timer_off_outlined,
    );
  }

  return (
    title: 'تعذّر تحميل البيانات',
    message: msg,
    icon: Icons.error_outline,
  );
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

  showAppSnackBar(context, message, type: AppSnackBarType.error);
}
