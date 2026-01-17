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
        if (x is Map) {
          parsed.add(Map<String, dynamic>.from(x));
        }
      }

      final visible = parsed.where((e) => !_shouldHideFromInbox(e)).toList();

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

  Future<void> _routeFromInboxEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> item,
  }) async {
    final role = await _currentRole();

    // IMPORTANT:
    // بعض الأحداث لا تأتي كـ event_type واضح، لكن تأتي كـ payload.status
    final status = (payload["status"] ?? "").toString().toLowerCase();

    // 1) Adherence (taken/skipped) -> go to adherence tab
    if (status == "taken" || status == "skipped") {
      if (!mounted) return;
      context.go("/app/record/adherence");
      return;
    }

    // 2) no_show -> go to appointments tab
    if (status == "no_show") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // Appointment-related events -> appointments tab
    if (eventType == "appointment_created" ||
        eventType == "appointment_confirmed" ||
        eventType == "appointment_cancelled" ||
        eventType == "appointment_no_show" ||
        eventType == "APPOINTMENT_NO_SHOW") {
      if (!mounted) return;
      context.go("/app/appointments");
      return;
    }

    // Clinical order created -> order details in record
    if (eventType == "CLINICAL_ORDER_CREATED" ||
        eventType == "clinical_order_created") {
      final rawOrderId = (item["object_id"] ?? payload["order_id"]);
      final orderId = int.tryParse(rawOrderId?.toString() ?? "");

      if (orderId != null) {
        if (!mounted) return;
        context.go("/app/record/orders/$orderId?role=$role");
        return;
      }

      if (!mounted) return;
      context.go("/app/record");
      return;
    }

    // File uploaded/reviewed -> record (files tab)
    if (eventType == "file_uploaded" || eventType == "file_reviewed") {
      if (!mounted) return;
      context.go("/app/record/files");
      return;
    }

    // Prescription created -> prescriptions tab
    if (eventType == "PRESCRIPTION_CREATED" ||
        eventType == "prescription_created") {
      if (!mounted) return;
      context.go("/app/record/prescripts");
      return;
    }

    // Adherence created (explicit) -> adherence tab
    if (eventType == "ADHERENCE_CREATED" || eventType == "adherence_created") {
      if (!mounted) return;
      context.go("/app/record/adherence");
      return;
    }

    // Default fallback
    if (!mounted) return;
    showAppSnackBar(
      context,
      "لا يوجد توجيه لهذا النوع: $eventType",
      type: AppSnackBarType.info,
    );
  }

  String _titleForEvent(String eventType, Map<String, dynamic> payload) {
    final status = (payload["status"] ?? "").toString().toLowerCase();

    // taken/skipped قد تأتي بدون eventType واضح
    if (status == "taken" || status == "skipped") {
      return "تسجيل التزام دوائي";
    }

    if (status == "no_show") {
      return "لم يتم الحضور للموعد";
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
      case "adherence_created":
      case "ADHERENCE_CREATED":
        return "تسجيل التزام دوائي";
      default:
        return "إشعار";
    }
  }

  String _bodyForEvent(String eventType, Map<String, dynamic> payload) {
    final title = payload["title"]?.toString();
    final filename = payload["filename"]?.toString();
    final reviewStatus = payload["review_status"]?.toString();
    final orderCategory = payload["order_category"]?.toString();
    final status = payload["status"]?.toString();

    // taken/skipped نص واضح
    final statusLower = (status ?? "").toLowerCase();
    if (statusLower == "taken") return "تم تسجيل تناول الجرعة.";
    if (statusLower == "skipped") return "تم تسجيل تخطي الجرعة.";
    if (statusLower == "no_show") return "تم وضع الموعد بحالة عدم حضور.";

    switch (eventType) {
      case "CLINICAL_ORDER_CREATED":
      case "clinical_order_created":
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
    final status = (payload["status"] ?? "").toString().toLowerCase();

    if (status == "taken" || status == "skipped") return Icons.check_circle;
    if (status == "no_show") return Icons.event_busy;

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
      case "adherence_created":
      case "ADHERENCE_CREATED":
        return Icons.check_circle;
      default:
        return Icons.notifications;
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

                    final rawId = item["id"];
                    final int id =
                        rawId is int ? rawId : int.tryParse("$rawId") ?? 0;

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

                    final title = _titleForEvent(eventType, payload);
                    final body = _bodyForEvent(eventType, payload);

                    final createdAt = item["created_at"]?.toString() ?? "";

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
                              "#$id • $createdAt",
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
