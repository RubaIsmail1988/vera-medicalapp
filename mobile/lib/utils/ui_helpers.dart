import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '/utils/api_exception.dart';
import '/utils/navigation_keys.dart';

enum AppSnackBarType { info, success, warning, error }

// ---------------------------------------------------------------------------
// SnackBar (موحّد)
// ---------------------------------------------------------------------------

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
    return 'انتهت الجلسة، يرجى تسجيل الدخول مجدداً.';
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
    return 'حدث خطأ غير متوقع. حاول مرة أخرى لاحقاً.';
  }

  return extractApiErrorMessage(data, fallback: 'تعذّر تنفيذ العملية.');
}

String mapExceptionToArabicMessage(
  Object error, {
  String fallback = 'حدث خطأ غير متوقع. حاول مرة أخرى.',
}) {
  if (error is TimeoutException) {
    return 'انتهت مهلة الاتصال. حاول مرة أخرى.';
  }

  if (error is SocketException) {
    return 'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
  }

  if (error is HandshakeException) {
    return 'تعذّر إنشاء اتصال آمن. حاول مرة أخرى لاحقًا.';
  }

  if (error is HttpException) {
    return 'تعذّر الاتصال بالخادم. تحقق من الإنترنت.';
  }

  final text = error.toString();
  final lower = text.toLowerCase();

  final arabicLooksOffline =
      text.contains('تعذّر الاتصال بالخادم') ||
      text.contains('تحقق من الإنترنت') ||
      text.contains('تحقق من الاتصال') ||
      text.contains('لا يوجد اتصال');

  if (arabicLooksOffline) {
    return 'لا يوجد اتصال بالإنترنت. تحقق من الاتصال وحاول مرة أخرى.';
  }

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

void showActionErrorSnackBar(
  BuildContext? context, {
  int? statusCode,
  Object? data,
  Object? exception,
  String fallback = 'تعذّر تنفيذ العملية.',
}) {
  final message = () {
    if (exception is ApiException) {
      return ApiExceptionUtils.extractMessage(exception, fallback: fallback);
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

class AppFetchStateView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const AppFetchStateView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final state = mapFetchExceptionToInlineState(error);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // يمنع overflow على الشاشات القصيرة أو داخل Tabs
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: AppInlineErrorState(
                title: state.title,
                message: state.message,
                icon: state.icon,
                onRetry: onRetry,
              ),
            ),
          ),
        );
      },
    );
  }
}

({String title, String message, IconData icon}) mapFetchExceptionToInlineState(
  Object error,
) {
  final msg = mapExceptionToArabicMessage(
    error,
    fallback: 'تعذّر تحميل البيانات. حاول مرة أخرى.',
  );

  // قرار UI: كل أخطاء الـ Fetch -> نفس أيقونة الوايفاي
  // (حتى لو كانت 400/500/Parsing/Unknown)
  return (
    title: 'تعذّر تحميل البيانات',
    message: msg,
    icon: Icons.wifi_off_rounded,
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
