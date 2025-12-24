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
  if (messenger == null) {
    // لا يوجد ScaffoldMessenger جاهز (حالة نادرة جداً أثناء bootstrap)
    return;
  }

  if (clearPrevious) {
    messenger.clearSnackBars();
  }

  final ColorScheme? cs =
      context != null ? Theme.of(context).colorScheme : null;

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

/// اختصار شائع
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
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );

  return result == true;
}
