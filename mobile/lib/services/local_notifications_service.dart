// ----------------- mobile/lib/services/local_notifications_service.dart -----------------
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/utils/navigation_keys.dart';
import '/utils/notification_routing.dart';

class LocalNotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = "vera_reminders";
  static const String _channelName = "Vera Reminders";
  static const String _channelDesc = "Appointment and medication reminders";

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
      // ملاحظة: onDidReceiveBackgroundNotificationResponse يتطلب top-level handler،
      // ونتركه خارج الـ MVP حالياً.
    );

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();

      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications] permission granted=$granted");
      }

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );
      await android.createNotificationChannel(channel);
    }

    _initialized = true;

    if (kDebugMode) {
      // ignore: avoid_print
      print("[LocalNotifications] initialized. tz.local=${tz.local}");
    }
  }

  static NotificationDetails _details() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    return const NotificationDetails(android: androidDetails);
  }

  static Future<AndroidScheduleMode> _bestAndroidScheduleMode() async {
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (android == null) return mode;

    try {
      final canExact = await android.canScheduleExactNotifications();

      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications] canScheduleExact=$canExact");
      }

      if (canExact == true) {
        mode = AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        await android.requestExactAlarmsPermission();
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications] exact alarm check failed: $e");
      }
    }

    return mode;
  }

  // ---------------------------------------------------------------------------
  // Appointment reminders (scheduled)
  // ---------------------------------------------------------------------------
  static int _idDayBefore(int appointmentId) => appointmentId * 10 + 1;
  static int _idHourBefore(int appointmentId) => appointmentId * 10 + 2;

  static Future<void> scheduleAppointmentReminders({
    required int appointmentId,
    required String doctorName,
    required DateTime appointmentDateTimeLocal,
  }) async {
    await init();
    await cancelAppointmentReminders(appointmentId);

    final mode = await _bestAndroidScheduleMode();

    final appointmentAt = tz.TZDateTime.from(
      appointmentDateTimeLocal,
      tz.local,
    );

    final oneHourBefore = appointmentAt.subtract(const Duration(hours: 1));
    final oneDayBefore = appointmentAt.subtract(const Duration(days: 1));

    final now = tz.TZDateTime.now(tz.local);

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        "[LocalNotifications][APPT] now=$now appointmentAt=$appointmentAt "
        "hourBefore=$oneHourBefore dayBefore=$oneDayBefore apId=$appointmentId mode=$mode",
      );
    }

    // قبل ساعة
    if (oneHourBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idHourBefore(appointmentId),
        "تذكير بالموعد",
        "موعدك بعد ساعة — الطبيب: $doctorName",
        oneHourBefore,
        _details(),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: "appointment:$appointmentId:hour",
      );
    } else {
      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications][APPT] skip hourBefore (in the past)");
      }
    }

    // قبل يوم
    if (oneDayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        _idDayBefore(appointmentId),
        "تذكير بالموعد",
        "موعدك غداً — الطبيب: $doctorName",
        oneDayBefore,
        _details(),
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: "appointment:$appointmentId:day",
      );
    } else {
      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications][APPT] skip dayBefore (in the past)");
      }
    }

    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      // ignore: avoid_print
      print("[LocalNotifications] pending count=${pending.length}");
    }
  }

  static Future<void> cancelAppointmentReminders(int appointmentId) async {
    await init();
    await _plugin.cancel(_idDayBefore(appointmentId));
    await _plugin.cancel(_idHourBefore(appointmentId));

    if (kDebugMode) {
      // ignore: avoid_print
      print("[LocalNotifications] cancelled reminders apId=$appointmentId");
    }
  }

  // ---------------------------------------------------------------------------
  // Instant notifications
  // ---------------------------------------------------------------------------
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    await _plugin.show(id, title, body, _details(), payload: payload);

    if (kDebugMode) {
      final pending = await _plugin.pendingNotificationRequests();
      // ignore: avoid_print
      print("[LocalNotifications] showInstant done. pending=${pending.length}");
    }
  }

  // ---------------------------------------------------------------------------
  // Inbox events (Polling) - shown immediately
  // ---------------------------------------------------------------------------
  static Future<void> showInboxEvent({
    required int notificationId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await init();

    // Avoid collision with appointment reminder ids (appointmentId*10+X)
    final safeId = 1000000 + notificationId;

    try {
      await _plugin.show(
        safeId,
        title,
        body,
        _details(),
        payload: data != null ? jsonEncode(data) : null,
      );

      if (kDebugMode) {
        // ignore: avoid_print
        print(
          "[LocalNotifications] showInboxEvent id=$notificationId safeId=$safeId title=$title",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print("[LocalNotifications] showInboxEvent failed: $e");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tap handling (Routing by payload)
  // ---------------------------------------------------------------------------
  static void _handleNotificationTap(String? payload) {
    // ignore: unawaited_futures
    _handleNotificationTapAsync(payload);
  }

  static Future<void> _handleNotificationTapAsync(String? payload) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    // role من prefs لتحديد التوجيه (وخاصة record/orders)
    final prefs = await SharedPreferences.getInstance();
    final currentRole = (prefs.getString("user_role") ?? "patient").trim();
    final safeRole = (currentRole == "doctor") ? "doctor" : "patient";

    // 1) Scheduled appointment reminder payload format: appointment:<id>:hour|day
    if (payload != null && payload.startsWith("appointment:")) {
      // MVP: نذهب لتبويب المواعيد
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/appointments");
      return;
    }

    // 2) Polling payload is JSON غالباً
    final Map<String, dynamic> data = NotificationRouting.parsePayload(payload);

    // بعض الأحداث تميزها عبر status أكثر من event_type (مثل taken/no_show)
    final String eventType =
        (data["event_type"] ?? data["type"] ?? "notification").toString();
    final String status = (data["status"] ?? "").toString();

    // 2.a) حالات مطلوبة حسب طلبك:
    // - taken/skipped -> adherence
    if (status == "taken" || status == "skipped") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/record/adherence");
      return;
    }

    // - no_show -> appointments
    if (status == "no_show") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/appointments");
      return;
    }

    // 2.b) توجيهات أساسية مفيدة (حتى لو resolveLocation لم يغطيها)
    if (eventType == "MEDICAL_FILE_DELETED") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/record/files");
      return;
    }

    if (eventType == "file_uploaded" || eventType == "file_reviewed") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/record/files");
      return;
    }

    if (eventType == "PRESCRIPTION_CREATED" ||
        eventType == "prescription_created") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/record/prescripts");
      return;
    }

    if (eventType == "appointment_created" ||
        eventType == "appointment_confirmed" ||
        eventType == "appointment_cancelled") {
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/appointments");
      return;
    }

    // Clinical order created: حاول فتح تفاصيل الطلب إذا أمكن
    if (eventType == "CLINICAL_ORDER_CREATED" ||
        eventType == "clinical_order_created") {
      final rawOrderId =
          data["order_id"] ?? data["object_id"] ?? data["entity_id"];
      final orderId = int.tryParse(rawOrderId?.toString() ?? "");
      if (orderId != null) {
        // ignore: use_build_context_synchronously
        GoRouter.of(context).go("/app/record/orders/$orderId?role=$safeRole");
        return;
      }
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/record");
      return;
    }

    // 3) fallback: استخدم notification_routing.dart إن كان يغطي الحدث
    final location = NotificationRouting.resolveLocation(
      data,
      currentRole: safeRole,
    );

    if (location.trim().isEmpty) {
      // fallback نهائي: افتح Inbox
      // ignore: use_build_context_synchronously
      GoRouter.of(context).go("/app/inbox");
      return;
    }

    // ignore: use_build_context_synchronously
    GoRouter.of(context).go(location);
  }
}
