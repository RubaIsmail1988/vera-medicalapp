import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final ClinicalService clinicalService;

  bool loading = true;
  bool refreshing = false;

  List<Map<String, dynamic>> items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    // ignore: unawaited_futures
    loadInbox();
  }

  bool _shouldHideFromInbox(Map<String, dynamic> item) {
    final eventType = (item["event_type"] ?? "").toString();
    if (eventType != "MEDICAL_FILE_DELETED") return false;

    final payloadRaw = item["payload"];
    final Map<String, dynamic> payload =
        payloadRaw is Map
            ? Map<String, dynamic>.from(payloadRaw)
            : <String, dynamic>{};

    final reason = (payload["reason"] ?? "").toString();

    final actorId = int.tryParse(item["actor"]?.toString() ?? "") ?? 0;
    final recipientId =
        int.tryParse(item["recipient_id"]?.toString() ?? "") ?? 0;

    final isSelf = actorId != 0 && actorId == recipientId;

    // سياسة MVP: حذف المريض لملفه بنفسه لا يظهر في Inbox
    if (isSelf && reason == "deleted_by_patient") return true;

    // وبشكل عام الحدث لا يملك وجهة واضحة -> نخفيه
    return true;
  }

  DateTime? _parseCreatedAt(Map<String, dynamic> item) {
    final raw = (item["created_at"] ?? "").toString().trim();
    if (raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  int _parseId(Map<String, dynamic> item) {
    final raw = item["id"];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? "") ?? 0;
  }

  Future<void> loadInbox() async {
    setState(() => loading = true);

    try {
      final resp = await clinicalService.fetchInbox(limit: 50);

      if (!mounted) return;

      if (resp.statusCode != 200) {
        showAppSnackBar(
          context,
          "فشل تحميل Inbox (status=${resp.statusCode})",
          type: AppSnackBarType.error,
        );
        setState(() {
          items = <Map<String, dynamic>>[];
          loading = false;
        });
        return;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        showAppSnackBar(
          context,
          "استجابة Inbox غير صحيحة",
          type: AppSnackBarType.error,
        );
        setState(() {
          items = <Map<String, dynamic>>[];
          loading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> parsed = <Map<String, dynamic>>[];
      for (final x in decoded) {
        if (x is Map) parsed.add(Map<String, dynamic>.from(x));
      }

      final visible = parsed.where((e) => !_shouldHideFromInbox(e)).toList();

      // ترتيب: الأحدث أولاً (created_at desc) ثم id desc كـ tie-breaker
      visible.sort((a, b) {
        final adt = _parseCreatedAt(a);
        final bdt = _parseCreatedAt(b);

        if (adt != null && bdt != null) {
          final cmp = bdt.compareTo(adt); // desc
          if (cmp != 0) return cmp;
        } else if (adt == null && bdt != null) {
          return 1; // b first
        } else if (adt != null && bdt == null) {
          return -1; // a first
        }

        // tie-break by id (desc)
        return _parseId(b).compareTo(_parseId(a));
      });

      setState(() {
        items = visible;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        "خطأ أثناء تحميل Inbox: $e",
        type: AppSnackBarType.error,
      );
      setState(() {
        items = <Map<String, dynamic>>[];
        loading = false;
      });
    }
  }

  Future<void> onRefresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await loadInbox();
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;
      setState(() => refreshing = false);
    }
  }

  Future<String> _currentRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('user_role') ?? 'patient').trim();
    return role.isEmpty ? 'patient' : role;
  }

  String _actorNameFrom(
    Map<String, dynamic> item,
    Map<String, dynamic> payload,
  ) {
    final s1 = item["actor_display_name"]?.toString();
    if (s1 != null && s1.trim().isNotEmpty) return s1.trim();

    final s2 = payload["actor_name"]?.toString();
    if (s2 != null && s2.trim().isNotEmpty) return s2.trim();

    final actorId = item["actor"]?.toString() ?? "";
    if (actorId.trim().isNotEmpty) return "User #$actorId";
    return "مستخدم";
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? "");
  }

  Future<void> _routeFromInboxEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> item,
  }) async {
    final role = await _currentRole();
    final safeRole = role.trim() == "doctor" ? "doctor" : "patient";

    // status-driven
    final status = (payload["status"] ?? "").toString().toLowerCase().trim();

    if (status == "taken" || status == "skipped") {
      if (!mounted) return;
      context.go("/app/record/adherence");
      return;
    }

    if (status == "no_show") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // ------------------- NEW: urgent + emergency absence cases -------------------
    // 1) urgent_request_scheduled -> patient -> appointments
    if (eventType == "urgent_request_scheduled") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // 2) urgent_request_rejected -> patient -> appointments
    if (eventType == "urgent_request_rejected") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // 3) appointment_cancelled_due_to_emergency_absence -> appointments

    if (eventType == "appointment_cancelled_due_to_emergency_absence") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // 4) urgent request without slots:
    // you mentioned: "طلب عاجل بدون مواعيد متاحة"
    // قد يصل بأكثر من اسم حسب الباك؛ نعالج أشهر احتمالات بأمان
    if (eventType == "urgent_request_no_slots" ||
        eventType == "urgent_request_no_availability" ||
        eventType == "urgent_request_created_no_slots" ||
        eventType == "urgent_request_without_slots" ||
        eventType == "urgent_request_created") {
      if (!mounted) return;
      // الطبيب: شاشة الطلبات العاجلة
      if (safeRole == "doctor") {
        context.go("/app/appointments/urgent-requests");
        return;
      }
      // المريض: المواعيد (مراجعة الطلب/النتيجة)
      context.go("/app/appointments");
      return;
    }
    // ---------------------------------------------------------------------------

    if (eventType == "appointment_created" ||
        eventType == "appointment_confirmed" ||
        eventType == "appointment_cancelled" ||
        eventType == "appointment_no_show" ||
        eventType == "APPOINTMENT_NO_SHOW") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    if (eventType == "CLINICAL_ORDER_CREATED" ||
        eventType == "clinical_order_created") {
      final rawOrderId =
          (item["object_id"] ?? payload["order_id"] ?? payload["entity_id"]);
      final orderId = int.tryParse(rawOrderId?.toString() ?? "");

      if (orderId != null) {
        if (!mounted) return;
        context.go("/app/record/orders/$orderId?role=$safeRole");
        return;
      }

      if (!mounted) return;
      context.go("/app/record");
      return;
    }

    if (eventType == "file_uploaded" || eventType == "file_reviewed") {
      if (!mounted) return;
      context.go("/app/record/files");
      return;
    }

    if (eventType == "PRESCRIPTION_CREATED" ||
        eventType == "prescription_created") {
      if (!mounted) return;
      context.go("/app/record/prescripts");
      return;
    }

    if (eventType == "ADHERENCE_CREATED" ||
        eventType == "adherence_created" ||
        eventType == "MEDICATION_ADHERENCE_RECORDED") {
      if (!mounted) return;
      context.go("/app/record/adherence");
      return;
    }

    // fallback: لو السيرفر يرسل route داخل payload
    final rawRoute =
        (payload["route"] ?? item["route"])?.toString().trim() ?? "";
    if (rawRoute.startsWith("/app")) {
      if (!mounted) return;

      // إذا كان route خاص بطلب order، نضمن role (web-safe)
      final uri = Uri.tryParse(rawRoute);
      if (uri != null && uri.path.startsWith("/app/record/orders/")) {
        final qp = Map<String, String>.from(uri.queryParameters);
        qp.putIfAbsent("role", () => safeRole);

        // enrich optional
        final patientId = _toInt(payload["patient_id"]);
        final appointmentId = _toInt(payload["appointment_id"]);
        if (safeRole == "doctor" && patientId != null && patientId > 0) {
          qp.putIfAbsent("patientId", () => patientId.toString());
        }
        if (appointmentId != null && appointmentId > 0) {
          qp.putIfAbsent("appointmentId", () => appointmentId.toString());
        }

        final safe = Uri(path: uri.path, queryParameters: qp).toString();
        context.go(safe);
        return;
      }

      context.go(rawRoute);
      return;
    }

    if (!mounted) return;
    showAppSnackBar(
      context,
      "لا يوجد توجيه لهذا النوع: $eventType",
      type: AppSnackBarType.info,
    );
  }

  String _titleForEvent(String eventType, Map<String, dynamic> payload) {
    final payloadTitle = payload["title"]?.toString();
    if (payloadTitle != null && payloadTitle.trim().isNotEmpty) {
      return payloadTitle.trim();
    }

    final status = (payload["status"] ?? "").toString().toLowerCase().trim();
    if (status == "taken" || status == "skipped") return "تسجيل التزام دوائي";
    if (status == "no_show") return "لم يتم الحضور للموعد";

    // NEW: urgent + emergency absence titles (fallback)
    switch (eventType) {
      case "urgent_request_scheduled":
        return "تم تحديد موعد عاجل";
      case "urgent_request_rejected":
        return "تم رفض طلب موعد عاجل";
      case "urgent_request_no_slots":
      case "urgent_request_no_availability":
      case "urgent_request_created_no_slots":
      case "urgent_request_without_slots":
      case "urgent_request_created":
        return "طلب عاجل بدون مواعيد متاحة";
      case "appointment_cancelled_due_to_emergency_absence":
      case "appointmen_cancelled_due_to_emergency_absence":
        return "تم إلغاء موعدك بسبب غياب طارئ";
    }

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
      default:
        return "إشعار";
    }
  }

  String _bodyForEvent(String eventType, Map<String, dynamic> payload) {
    final payloadMsg = payload["message"]?.toString();
    if (payloadMsg != null && payloadMsg.trim().isNotEmpty) {
      return payloadMsg.trim();
    }

    final filename = payload["filename"]?.toString();
    final reviewStatus = payload["review_status"]?.toString();
    final orderCategory = payload["order_category"]?.toString();
    final status = payload["status"]?.toString();

    final statusLower = (status ?? "").toLowerCase().trim();
    if (statusLower == "taken") return "تم تسجيل تناول الجرعة.";
    if (statusLower == "skipped") return "تم تسجيل تخطي الجرعة.";
    if (statusLower == "no_show") return "تم وضع الموعد بحالة عدم حضور.";

    // NEW: urgent + emergency absence body (fallback)
    switch (eventType) {
      case "urgent_request_scheduled":
        return "تم تحديد موعد عاجل. يمكنك مراجعة التفاصيل من شاشة المواعيد.";
      case "urgent_request_rejected":
        return "تم رفض طلب الموعد العاجل. يمكنك مراجعة التفاصيل من شاشة المواعيد.";
      case "appointment_cancelled_due_to_emergency_absence":
      case "appointmen_cancelled_due_to_emergency_absence":
        return "تم إلغاء الموعد بسبب غياب طارئ لدى الطبيب. يرجى مراجعة المواعيد.";
      case "urgent_request_no_slots":
      case "urgent_request_no_availability":
      case "urgent_request_created_no_slots":
      case "urgent_request_without_slots":
      case "urgent_request_created":
        return "لا توجد مواعيد متاحة حاليًا للطلب العاجل. يرجى مراجعة شاشة المواعيد.";
    }

    switch (eventType) {
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
        final title = payload["title"]?.toString();
        if (title != null && title.trim().isNotEmpty) return "طلب: $title";
        if (orderCategory != null && orderCategory.isNotEmpty) {
          return "النوع: $orderCategory";
        }
        return "تم إنشاء طلب جديد.";
      case "file_uploaded":
        if (filename != null && filename.trim().isNotEmpty) {
          return "الملف: $filename";
        }
        return "تم رفع ملف جديد.";
      case "file_reviewed":
        if (reviewStatus != null && reviewStatus.isNotEmpty) {
          return "النتيجة: $reviewStatus";
        }
        return "تمت مراجعة ملف.";
      default:
        if (status != null && status.isNotEmpty) return "الحالة: $status";
        return "تفاصيل غير متوفرة.";
    }
  }

  IconData _iconForEvent(String eventType, Map<String, dynamic> payload) {
    final status = (payload["status"] ?? "").toString().toLowerCase().trim();

    if (status == "taken" || status == "skipped") return Icons.check_circle;
    if (status == "no_show") return Icons.event_busy;

    // NEW: urgent + emergency absence icons
    switch (eventType) {
      case "urgent_request_scheduled":
        return Icons.flash_on;
      case "urgent_request_rejected":
        return Icons.block;
      case "urgent_request_no_slots":
      case "urgent_request_no_availability":
      case "urgent_request_created_no_slots":
      case "urgent_request_without_slots":
      case "urgent_request_created":
        return Icons.warning_amber;
      case "appointment_cancelled_due_to_emergency_absence":
      case "appointmen_cancelled_due_to_emergency_absence":
        return Icons.event_busy;
    }

    switch (eventType) {
      case "appointment_created":
        return Icons.event_note;
      case "appointment_confirmed":
        return Icons.event_available;
      case "appointment_cancelled":
        return Icons.event_busy;
      case "appointment_no_show":
      case "APPOINTMENT_NO_SHOW":
        return Icons.event_busy;
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
        return Icons.science;
      case "file_uploaded":
        return Icons.upload_file;
      case "file_reviewed":
        return Icons.verified;
      case "PRESCRIPTION_CREATED":
      case "prescription_created":
        return Icons.medication;
      default:
        return Icons.notifications;
    }
  }

  String _formatCreatedAt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "";

    try {
      final dt = DateTime.parse(s).toLocal();

      String two(int x) => x.toString().padLeft(2, "0");
      final y = dt.year;
      final m = two(dt.month);
      final d = two(dt.day);
      final hh = two(dt.hour);
      final mm = two(dt.minute);

      return "$y-$m-$d $hh:$mm";
    } catch (_) {
      return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Inbox")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inbox"),
        actions: [
          IconButton(
            tooltip: "تحديث",
            onPressed: refreshing ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child:
            items.isEmpty
                ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text("لا يوجد إشعارات بعد")),
                  ],
                )
                : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    final payloadRaw = item["payload"];
                    final Map<String, dynamic> payload =
                        payloadRaw is Map
                            ? Map<String, dynamic>.from(payloadRaw)
                            : <String, dynamic>{};

                    final eventType =
                        (item["event_type"] ??
                                payload["type"] ??
                                payload["status"] ??
                                "notification")
                            .toString();

                    final actorName = _actorNameFrom(item, payload);

                    final title = _titleForEvent(eventType, payload);
                    final body = _bodyForEvent(eventType, payload);

                    final createdAtRaw = item["created_at"]?.toString() ?? "";
                    final createdAt = _formatCreatedAt(createdAtRaw);

                    return Card(
                      child: ListTile(
                        leading: Icon(_iconForEvent(eventType, payload)),
                        title: Text(title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(body),
                            const SizedBox(height: 6),
                            Text(
                              "من: $actorName",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 6),
                            if (createdAt.isNotEmpty)
                              Text(
                                "التاريخ والوقت: $createdAt",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        onTap: () async {
                          await _routeFromInboxEvent(
                            eventType: eventType,
                            payload: payload,
                            item: item,
                          );
                        },
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
