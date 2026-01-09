import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/constants.dart';
import '/utils/ui_helpers.dart';

class OrderDetailsScreen extends StatefulWidget {
  /// Final role determined by route builder (web-safe).
  final String role; // doctor | patient
  final int orderId;

  /// For doctor: used for back navigation to /app/record?patientId=...
  final int? doctorPatientId;

  /// Optional: keep appointment context when returning back.
  final int? appointmentId;

  const OrderDetailsScreen({
    super.key,
    required this.role,
    required this.orderId,
    this.doctorPatientId,
    this.appointmentId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final ClinicalService clinicalService;

  bool loading = true;
  String? errorMessage;

  Map<String, dynamic>? order;
  List<Map<String, dynamic>> files = [];

  bool get isDoctor => widget.role.trim().toLowerCase() == "doctor";
  bool get isPatient => !isDoctor;

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });

    final orderRes = await clinicalService.getOrderDetails(widget.orderId);
    if (!mounted) return;

    if (orderRes.statusCode == 401) {
      final msg = "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    if (orderRes.statusCode == 403) {
      final msg = "لا تملك الصلاحية لعرض تفاصيل هذا الطلب.";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    if (orderRes.statusCode != 200) {
      final msg = "فشل تحميل تفاصيل الطلب (${orderRes.statusCode}).";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    final Map<String, dynamic> orderJson =
        jsonDecode(orderRes.body) as Map<String, dynamic>;

    final filesRes = await clinicalService.listOrderFiles(widget.orderId);
    if (!mounted) return;

    if (filesRes.statusCode == 401) {
      final msg = "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    if (filesRes.statusCode == 403) {
      final msg = "لا تملك الصلاحية لعرض ملفات هذا الطلب.";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    if (filesRes.statusCode != 200) {
      final msg = "فشل تحميل الملفات (${filesRes.statusCode}).";
      setState(() {
        loading = false;
        errorMessage = msg;
      });
      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    final decodedFiles = jsonDecode(filesRes.body);
    final List<Map<String, dynamic>> filesList =
        decodedFiles is List
            ? decodedFiles.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    if (!mounted) return;
    setState(() {
      order = orderJson;
      files = filesList;
      loading = false;
      errorMessage = null;
    });
  }

  // ---------------- Helpers ----------------

  String _categoryLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return "تحاليل";
    if (v == "medical_imaging") return "صور";
    return raw;
  }

  IconData _orderCategoryIcon(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return Icons.science_outlined; // 🧪
    if (v == "medical_imaging") return Icons.medical_services_outlined; // 🩻
    return Icons.insert_drive_file_outlined;
  }

  String _normalizedReviewStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "pending" || v == "pending_review" || v == "pending-review") {
      return "pending_review";
    }
    if (v == "approved") return "approved";
    if (v == "rejected") return "rejected";
    return v.isNotEmpty ? v : "pending_review";
  }

  String _reviewStatusLabelAr(String normalized) {
    if (normalized == "pending_review") return "قيد المراجعة";
    if (normalized == "approved") return "مقبول";
    if (normalized == "rejected") return "مرفوض";
    return normalized;
  }

  String _resolveFileUrl(String urlOrPath) {
    final trimmed = urlOrPath.trim();
    if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
      return trimmed;
    }
    if (trimmed.startsWith("/")) return "$baseUrl$trimmed";
    return "$baseUrl/$trimmed";
  }

  bool _isImage(String nameOrUrl) {
    final lower = nameOrUrl.toLowerCase();
    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png");
  }

  bool _isPdf(String nameOrUrl) => nameOrUrl.toLowerCase().endsWith(".pdf");
  bool _isDicom(String nameOrUrl) => nameOrUrl.toLowerCase().endsWith(".dcm");

  Map<String, int> _filesSummary() {
    var pending = 0;
    var approved = 0;
    var rejected = 0;

    for (final f in files) {
      final raw = f["review_status"]?.toString() ?? "";
      final st = _normalizedReviewStatus(raw);
      if (st == "pending_review") pending++;
      if (st == "approved") approved++;
      if (st == "rejected") rejected++;
    }

    return {"pending": pending, "approved": approved, "rejected": rejected};
  }

  String _formatDateTimeShort(String iso) {
    final s = iso.trim();
    if (s.isEmpty) return "";
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;

    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(local.day)}/${two(local.month)}/${local.year} – ${two(local.hour)}:${two(local.minute)}";
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppSnackBar(context, "رابط غير صالح.", type: AppSnackBarType.error);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(
        context,
        "تعذر فتح الرابط. انسخه وافتحه يدويًا.",
        type: AppSnackBarType.warning,
      );
    }
  }

  Future<bool> _confirmDecision({required String actionLabel}) async {
    return showConfirmDialog(
      context,
      title: "تأكيد القرار",
      message: "هل أنت متأكد؟ لا يمكن التراجع.\nالإجراء: $actionLabel",
      confirmText: "تأكيد",
      cancelText: "إلغاء",
      danger: true,
    );
  }

  Future<String?> _askRejectNote() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("سبب الرفض (إجباري)"),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "اكتب سبب الرفض..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text("متابعة"),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _approveFile(int fileId) async {
    final confirmed = await _confirmDecision(actionLabel: "Approve");
    if (!mounted) return;
    if (!confirmed) return;

    final res = await clinicalService.approveFile(fileId);
    if (!mounted) return;

    if (res.statusCode == 200) {
      showAppSnackBar(context, "تمت الموافقة.", type: AppSnackBarType.success);
      await _loadAll();
      return;
    }

    final msg =
        (res.statusCode == 401)
            ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
            : (res.statusCode == 403)
            ? "لا تملك الصلاحية لمراجعة هذا الملف."
            : "فشل العملية (${res.statusCode}).";

    showAppSnackBar(context, msg, type: AppSnackBarType.error);
  }

  Future<void> _rejectFile(int fileId) async {
    final note = await _askRejectNote();
    if (!mounted) return;
    if (note == null) return;

    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      showAppSnackBar(
        context,
        "ملاحظة الرفض مطلوبة.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    final confirmed = await _confirmDecision(actionLabel: "Reject");
    if (!mounted) return;
    if (!confirmed) return;

    final res = await clinicalService.rejectFile(fileId, doctorNote: trimmed);
    if (!mounted) return;

    if (res.statusCode == 200) {
      showAppSnackBar(context, "تم الرفض.", type: AppSnackBarType.success);
      await _loadAll();
      return;
    }

    final msg =
        (res.statusCode == 401)
            ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
            : (res.statusCode == 403)
            ? "لا تملك الصلاحية لمراجعة هذا الملف."
            : "فشل العملية (${res.statusCode}).";

    showAppSnackBar(context, msg, type: AppSnackBarType.error);
  }

  void _goBackSmart() {
    final apptId = widget.appointmentId;

    // Doctor -> back to record with patientId (+ keep appointmentId if exists)
    if (isDoctor && widget.doctorPatientId != null) {
      final qp = <String, String>{
        "patientId": "${widget.doctorPatientId}",
        "role": "doctor",
      };
      if (apptId != null && apptId > 0) qp["appointmentId"] = "$apptId";
      context.go("/app/record?${Uri(queryParameters: qp).query}");
      return;
    }

    // Patient -> back to record (+ keep appointmentId if exists)
    if (apptId != null && apptId > 0) {
      context.go(
        "/app/record?${Uri(queryParameters: {"appointmentId": "$apptId", "role": "patient"}).query}",
      );
      return;
    }

    context.go("/app/record");
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final o = order;
    final summary = _filesSummary();

    final orderTitle = (o?["title"]?.toString() ?? "").trim();
    final doctorDisplayName =
        (o?["doctor_display_name"]?.toString() ?? "").trim().isNotEmpty
            ? (o?["doctor_display_name"]?.toString() ?? "").trim()
            : (o?["doctor"]?.toString() ?? "").trim();

    final doctorLabel =
        doctorDisplayName.isNotEmpty ? "د. $doctorDisplayName" : "";

    final categoryRaw = (o?["order_category"]?.toString() ?? "").trim();
    final orderIcon = _orderCategoryIcon(categoryRaw);

    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل الطلب"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackSmart,
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await _loadAll();
              if (!mounted) return;
              showAppSnackBar(
                // ignore: use_build_context_synchronously
                context,
                "تم التحديث.",
                type: AppSnackBarType.info,
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : (errorMessage != null)
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 12),
                      Text(errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadAll,
                          icon: const Icon(Icons.refresh),
                          label: const Text("إعادة المحاولة"),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : (o == null)
              ? const Center(child: Text("لا توجد بيانات لعرضها."))
              : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  orderTitle.isNotEmpty
                                      ? orderTitle
                                      : "بدون عنوان",
                                  style: Theme.of(context).textTheme.titleLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (doctorLabel.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Text(
                                  doctorLabel,
                                  style: Theme.of(context).textTheme.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text("النوع: ${_categoryLabel(categoryRaw)}"),
                          Text(
                            "الحالة: ${(o["status"]?.toString() ?? "open")}",
                          ),
                          Text(
                            "التاريخ: ${_formatDateTimeShort(o["created_at"]?.toString() ?? "")}",
                          ),
                          const SizedBox(height: 8),
                          if ((o["details"]?.toString() ?? "")
                              .trim()
                              .isNotEmpty)
                            Text(
                              "تعليمات/شروط: ${(o["details"]?.toString() ?? "").trim()}",
                            ),
                          const SizedBox(height: 12),
                          Text(
                            "ملخص الملفات: pending=${summary["pending"]} • approved=${summary["approved"]} • rejected=${summary["rejected"]}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Files
                  Card(
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(Icons.folder),
                          title: Text("الملفات المرتبطة بالطلب"),
                        ),
                        const Divider(height: 1),
                        if (files.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("لا توجد ملفات مرفوعة لهذا الطلب."),
                          )
                        else
                          ...files.map((f) {
                            final fileId = int.tryParse(
                              f["id"]?.toString() ?? "",
                            );

                            final rawUrl = (f["file"]?.toString() ?? "");
                            final fileUrl = _resolveFileUrl(rawUrl);

                            final filename =
                                (f["original_filename"]
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true)
                                    ? f["original_filename"].toString()
                                    : rawUrl;

                            final normalizedStatus = _normalizedReviewStatus(
                              f["review_status"]?.toString() ?? "",
                            );

                            final statusAr = _reviewStatusLabelAr(
                              normalizedStatus,
                            );

                            final doctorNote =
                                (f["doctor_note"]?.toString() ?? "").trim();

                            final isImg =
                                _isImage(filename) || _isImage(fileUrl);
                            final isPdf = _isPdf(filename) || _isPdf(fileUrl);
                            final isDcm =
                                _isDicom(filename) || _isDicom(fileUrl);

                            final canReview =
                                isDoctor &&
                                normalizedStatus == "pending_review" &&
                                fileId != null;

                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(child: Icon(orderIcon)),
                                  title: Text(
                                    filename.isNotEmpty ? filename : "ملف",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text("الحالة: $statusAr"),
                                      if (doctorNote.isNotEmpty)
                                        Text(
                                          "ملاحظة الطبيب: $doctorNote",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isImg) ...[
                                        SizedBox(
                                          height: 120,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.network(
                                              fileUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => const Center(
                                                    child: Text(
                                                      "تعذر تحميل الصورة.",
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await showDialog<void>(
                                              context: context,
                                              builder: (ctx) {
                                                return AlertDialog(
                                                  content: SizedBox(
                                                    width: double.maxFinite,
                                                    child: Image.network(
                                                      fileUrl,
                                                      fit: BoxFit.contain,
                                                      errorBuilder:
                                                          (
                                                            _,
                                                            __,
                                                            ___,
                                                          ) => const Text(
                                                            "تعذر تحميل الصورة.",
                                                          ),
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            ctx,
                                                          ),
                                                      child: const Text(
                                                        "إغلاق",
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                          icon: const Icon(Icons.image),
                                          label: const Text("عرض الصورة"),
                                        ),
                                      ] else if (isPdf) ...[
                                        ElevatedButton.icon(
                                          onPressed:
                                              () async =>
                                                  _openExternal(fileUrl),
                                          icon: const Icon(
                                            Icons.picture_as_pdf,
                                          ),
                                          label: const Text("فتح / تحميل PDF"),
                                        ),
                                      ] else if (isDcm) ...[
                                        ElevatedButton.icon(
                                          onPressed:
                                              () async =>
                                                  _openExternal(fileUrl),
                                          icon: const Icon(Icons.download),
                                          label: const Text(
                                            "تحميل فقط (DICOM)",
                                          ),
                                        ),
                                      ] else ...[
                                        ElevatedButton.icon(
                                          onPressed:
                                              () async =>
                                                  _openExternal(fileUrl),
                                          icon: const Icon(Icons.download),
                                          label: const Text("فتح / تحميل"),
                                        ),
                                      ],
                                      const SizedBox(height: 10),

                                      // Review buttons (doctor + pending only)
                                      if (isDoctor &&
                                          normalizedStatus ==
                                              "pending_review") ...[
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed:
                                                    canReview
                                                        ? () async =>
                                                            _approveFile(fileId)
                                                        : null,
                                                icon: const Icon(
                                                  Icons.check_circle_outline,
                                                ),
                                                label: const Text("Approve"),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed:
                                                    canReview
                                                        ? () async =>
                                                            _rejectFile(fileId)
                                                        : null,
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                                label: const Text("Reject"),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
