import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:go_router/go_router.dart';

import '/utils/navigation_keys.dart';
import '/utils/notification_routing.dart';

class LocalNotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = "vera_reminders";
  static const String _channelName = "Vera Reminders";
  static const String _channelDesc = "Appointment and medication reminders";

  static bool _initialized = false;

  // NOTE: نخزّن الدور هنا لتفادي await داخل tap handler (lint صارم)
  // يتم ضبطه عند بدء التطبيق + بعد login/logout.
  static String _currentRole = "patient";

  static void setCurrentRole(String role) {
    final r = role.trim();
    _currentRole = (r == "doctor") ? "doctor" : "patient";
    if (kDebugMode) {
      // ignore: avoid_print
      print("[LocalNotifications] role set=$_currentRole");
    }
  }

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
    }

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

    final safeId = 1000000 + notificationId;

    await _plugin.show(
      safeId,
      title,
      body,
      _details(),
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handling (NO async, NO context across gaps)
  // ---------------------------------------------------------------------------
  static void _handleNotificationTap(String? payload) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    final router = GoRouter.of(ctx);

    // role جاهزة بدون await
    final safeRole = _currentRole;

    // 1) appointment:<id>:hour|day
    if (payload != null && payload.startsWith("appointment:")) {
      router.go("/app/appointments");
      return;
    }

    // 2) Polling payload JSON
    final Map<String, dynamic> data = NotificationRouting.parsePayload(payload);

    final String eventType =
        (data["event_type"] ?? data["type"] ?? "notification").toString();
    final String status = (data["status"] ?? "").toString();

    if (status == "taken" || status == "skipped") {
      router.go("/app/record/adherence");
      return;
    }

    if (status == "no_show") {
      router.go("/app/appointments");
      return;
    }

    if (eventType == "MEDICAL_FILE_DELETED" ||
        eventType == "file_uploaded" ||
        eventType == "file_reviewed") {
      router.go("/app/record/files");
      return;
    }

    if (eventType == "PRESCRIPTION_CREATED" ||
        eventType == "prescription_created") {
      router.go("/app/record/prescripts");
      return;
    }

    if (eventType == "appointment_created" ||
        eventType == "appointment_confirmed" ||
        eventType == "appointment_cancelled") {
      router.go("/app/appointments");
      return;
    }

    if (eventType == "CLINICAL_ORDER_CREATED" ||
        eventType == "clinical_order_created") {
      final rawOrderId =
          data["order_id"] ?? data["object_id"] ?? data["entity_id"];
      final orderId = int.tryParse(rawOrderId?.toString() ?? "");
      if (orderId != null) {
        router.go("/app/record/orders/$orderId?role=$safeRole");
        return;
      }
      router.go("/app/record");
      return;
    }

    final location = NotificationRouting.resolveLocation(
      data,
      currentRole: safeRole,
    );

    router.go(location.trim().isEmpty ? "/app/inbox" : location);
  }
}
