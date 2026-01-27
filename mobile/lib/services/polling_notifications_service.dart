import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/clinical_service.dart';
import '/services/local_notifications_service.dart';
import '/services/auth_service.dart'; // kept because it's a constructor param type

class PollingNotificationsService {
  PollingNotificationsService({
    required this.authService,
    required this.clinicalService,
    this.intervalSeconds = 10,
    this.pageSize = 50,
  });

  final AuthService authService;
  final ClinicalService clinicalService;

  final int intervalSeconds;
  final int pageSize;

  Timer? timer;
  bool running = false;
  bool tickInProgress = false;

  // منع التكرار داخل نفس الجلسة
  final Set<int> deliveredIds = <int>{};

  // لحماية حالة "تبديل مستخدم" على نفس الجهاز
  int _cachedUserId = 0;

  // --------- lastSeen per user ---------
  Future<int> _currentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("user_id") ?? 0;
  }

  String _lastSeenKeyForUser(int userId) => "inbox_last_seen_id_$userId";

  Future<int> _getLastSeenId(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSeenKeyForUser(userId)) ?? 0;
  }

  Future<void> _setLastSeenId(int userId, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenKeyForUser(userId), value);
  }

  // --------- lifecycle ---------
  Future<void> start() async {
    if (running) return;
    running = true;

    try {
      await LocalNotificationsService.init();
    } catch (_) {}

    _cachedUserId = await _currentUserId();
    deliveredIds.clear();

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        "[Polling] start interval=${intervalSeconds}s pageSize=$pageSize userId=$_cachedUserId",
      );
    }

    // ignore: unawaited_futures
    _tick();

    timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      // ignore: unawaited_futures
      _tick();
    });
  }

  Future<void> stop() async {
    running = false;
    timer?.cancel();
    timer = null;
    tickInProgress = false;

    if (kDebugMode) {
      // ignore: avoid_print
      print("[Polling] stop");
    }
  }

  // --------- formatting helpers ---------
  String _two(int n) => n.toString().padLeft(2, "0");

  String _formatReadableDate(String? iso) {
    if (iso == null) return "";
    final s = iso.trim();
    if (s.isEmpty) return "";

    try {
      final dt = DateTime.parse(s).toLocal();
      return "${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}";
    } catch (_) {
      return s;
    }
  }

  // --------- filtering (UX policy) ---------
  bool _shouldIgnoreEvent({
    required String eventType,
    required int actorId,
    required int recipientId,
    required Map<String, dynamic> payload,
  }) {
    final et = eventType.trim().toUpperCase();

    if (et == "MEDICAL_FILE_DELETED") {
      final reason = (payload["reason"] ?? "").toString();
      final isSelf = actorId != 0 && recipientId != 0 && actorId == recipientId;

      if (isSelf && reason == "deleted_by_patient") {
        return true;
      }
    }

    return false;
  }

  // --------- helpers: payload-aware title/body ---------
  String _preferPayloadTitle(String eventType, Map<String, dynamic> payload) {
    final t = payload["title"]?.toString();
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return _titleForEventFallback(eventType, payload);
  }

  String _preferPayloadBody(String eventType, Map<String, dynamic> payload) {
    final msg = payload["message"]?.toString();
    if (msg != null && msg.trim().isNotEmpty) return msg.trim();

    final body = payload["body"]?.toString();
    if (body != null && body.trim().isNotEmpty) return body.trim();

    return _bodyForEventFallback(eventType, payload);
  }

  // --------- main tick ---------
  Future<void> _tick() async {
    if (!running) return;
    if (tickInProgress) return;
    tickInProgress = true;

    try {
      final userId = await _currentUserId();

      if (userId <= 0) {
        return;
      }

      if (userId != _cachedUserId) {
        _cachedUserId = userId;
        deliveredIds.clear();
      }

      final lastSeenId = await _getLastSeenId(userId);

      final resp = await clinicalService.fetchInbox(
        sinceId: lastSeenId,
        limit: pageSize,
      );

      if (resp.statusCode != 200) {
        if (kDebugMode) {
          // ignore: avoid_print
          print("[Polling] inbox status=${resp.statusCode} body=${resp.body}");
        }
        return;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) return;

      // ✅ نتابع أعلى ID تمت معالجته فعلاً (نجح show أو تجاهلناه بسياسة ignore)
      int maxProcessedId = lastSeenId;

      for (final item in decoded) {
        if (item is! Map) continue;

        final rawId = item["id"];
        final int? id =
            rawId is int ? rawId : int.tryParse(rawId?.toString() ?? "");
        if (id == null) continue;

        // منع التكرار داخل الجلسة
        if (deliveredIds.contains(id)) continue;

        final payloadRaw = item["payload"];
        final Map<String, dynamic> payload =
            (payloadRaw is Map)
                ? Map<String, dynamic>.from(payloadRaw)
                : <String, dynamic>{};

        final eventType =
            (item["event_type"] ?? payload["type"] ?? "notification")
                .toString();

        final rawActor = item["actor"];
        final actorId =
            rawActor is int
                ? rawActor
                : int.tryParse(rawActor?.toString() ?? "") ?? 0;

        final rawRecipient = item["recipient_id"];
        final recipientId =
            rawRecipient is int
                ? rawRecipient
                : int.tryParse(rawRecipient?.toString() ?? "") ?? 0;

        // فلترة (نعتبرها "processed" لكن بدون show)
        if (_shouldIgnoreEvent(
          eventType: eventType,
          actorId: actorId,
          recipientId: recipientId,
          payload: payload,
        )) {
          deliveredIds.add(id);
          if (id > maxProcessedId) maxProcessedId = id;
          continue;
        }

        final title = _preferPayloadTitle(eventType, payload);
        var body = _preferPayloadBody(eventType, payload);

        final actorName =
            (item["actor_display_name"] ??
                    payload["actor_name"] ??
                    payload["actor_display_name"] ??
                    "")
                .toString()
                .trim();

        final createdAtRaw =
            (item["created_at"] ?? payload["timestamp"] ?? "")
                .toString()
                .trim();
        final createdAt = _formatReadableDate(createdAtRaw);

        final parts = <String>[];
        if (actorName.isNotEmpty) parts.add("من: $actorName");
        if (createdAt.isNotEmpty) parts.add(createdAt);

        if (parts.isNotEmpty) {
          body = "$body — ${parts.join(" • ")}";
        }

        final data = <String, dynamic>{
          "event_type": eventType,
          "outbox_id": id,
          "actor_id": actorId,
          "recipient_id": recipientId,
          if (item["object_id"] != null)
            "object_id": item["object_id"].toString(),
          ...payload,
        };

        try {
          await LocalNotificationsService.showInboxEvent(
            notificationId: id,
            title: title,
            body: body,
            data: data,
          );

          // ✅ فقط بعد نجاح show نعتبره delivered ونرفع processed
          deliveredIds.add(id);
          if (id > maxProcessedId) maxProcessedId = id;
        } catch (e) {
          if (kDebugMode) {
            // ignore: avoid_print
            print("[Polling] show notification failed: $e");
          }
          // ❌ لا نضيف deliveredIds ولا نرفع lastSeen
        }
      }

      // ✅ تحديث lastSeen بشكل “غير سريع”: فقط للأحداث اللي تأكدنا إنها اتعالجت
      if (maxProcessedId > lastSeenId) {
        await _setLastSeenId(userId, maxProcessedId);

        if (kDebugMode) {
          // ignore: avoid_print
          print("[Polling] updated lastSeenId=$maxProcessedId userId=$userId");
        }
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print("[Polling] tick error: $e");
      }
    } finally {
      tickInProgress = false;
    }
  }

  // --------- fallback mapping ---------
  String _titleForEventFallback(
    String eventType,
    Map<String, dynamic> payload,
  ) {
    final status = (payload["status"] ?? "").toString().toLowerCase().trim();

    if (status == "taken") return "تم تسجيل تناول الدواء";
    if (status == "skipped") return "تم تسجيل تخطي الجرعة";
    if (status == "no_show") return "لم يتم الحضور للموعد";

    switch (eventType) {
      case "appointment_created":
        return "طلب موعد جديد";
      case "appointment_confirmed":
        return "تم تأكيد الموعد";
      case "appointment_cancelled":
        return "تم إلغاء الموعد";
      case "appointment_no_show":
      case "APPOINTMENT_NO_SHOW":
        return "لم يتم الحضور للموعد";
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
        return "طلب تحليل/صورة";
      case "file_uploaded":
        return "تم رفع ملف طبي";
      case "file_reviewed":
        return "تمت مراجعة ملف";
      case "PRESCRIPTION_CREATED":
      case "prescription_created":
        return "وصفة جديدة";
      case "ADHERENCE_CREATED":
      case "adherence_created":
      case "MEDICATION_ADHERENCE_RECORDED":
        return "تسجيل التزام دوائي";
      case "MEDICAL_FILE_DELETED":
        return "تم حذف ملف";
      default:
        return "إشعار جديد";
    }
  }

  String _bodyForEventFallback(String eventType, Map<String, dynamic> payload) {
    final title = payload["title"]?.toString();
    final status = (payload["status"] ?? "").toString().toLowerCase().trim();
    final orderCategory = payload["order_category"]?.toString();
    final filename = payload["filename"]?.toString();
    final reviewStatus = payload["review_status"]?.toString();
    final reason = payload["reason"]?.toString();

    if (status == "taken") return "تم تسجيل تناول الجرعة.";
    if (status == "skipped") return "تم تسجيل تخطي الجرعة.";
    if (status == "no_show") {
      return "يمكنك مراجعة تفاصيل الموعد من شاشة المواعيد.";
    }

    switch (eventType) {
      case "appointment_created":
        return "تم إرسال طلب موعد للطبيب.";
      case "appointment_confirmed":
        return "تم تأكيد موعدك.";
      case "appointment_cancelled":
        return "تم إلغاء الموعد.";
      case "appointment_no_show":
      case "APPOINTMENT_NO_SHOW":
        return "تم وضع الموعد كـ (لم يتم الحضور).";
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
        if (title != null && title.trim().isNotEmpty) return "طلب: $title";
        if (orderCategory != null && orderCategory.isNotEmpty) {
          return "النوع: $orderCategory";
        }
        return "تم إنشاء طلب تحليل/صورة.";
      case "file_uploaded":
        if (filename != null && filename.trim().isNotEmpty) {
          return "تم رفع الملف: $filename";
        }
        return "تم رفع ملف جديد.";
      case "file_reviewed":
        if (reviewStatus != null && reviewStatus.isNotEmpty) {
          return "حالة المراجعة: $reviewStatus";
        }
        return "تمت مراجعة ملفك.";
      case "MEDICAL_FILE_DELETED":
        if (reason != null && reason.isNotEmpty) {
          return "تم حذف الملف. السبب: $reason";
        }
        return "تم حذف الملف.";
      default:
        if ((payload["status"] ?? "").toString().trim().isNotEmpty) {
          return "الحالة: ${payload["status"]}";
        }
        return "تفاصيل غير متوفرة.";
    }
  }
}
