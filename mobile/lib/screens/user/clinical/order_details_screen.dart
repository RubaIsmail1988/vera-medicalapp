import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/constants.dart';
import '/utils/ui_helpers.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String role; // doctor | patient
  final int orderId;

  const OrderDetailsScreen({
    super.key,
    required this.role,
    required this.orderId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final ClinicalService clinicalService;

  bool loading = true;
  Map<String, dynamic>? order;
  List<Map<String, dynamic>> files = [];

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    loadAll();
  }

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  Future<void> loadAll() async {
    setState(() => loading = true);

    final orderRes = await clinicalService.getOrderDetails(widget.orderId);
    if (!mounted) return;

    if (orderRes.statusCode == 401) {
      setState(() => loading = false);
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (orderRes.statusCode == 403) {
      setState(() => loading = false);
      showAppSnackBar(context, "لا تملك الصلاحية لعرض تفاصيل هذا الطلب.");
      return;
    }
    if (orderRes.statusCode != 200) {
      setState(() => loading = false);
      showAppSnackBar(
        context,
        "فشل تحميل تفاصيل الطلب (${orderRes.statusCode}).",
      );
      return;
    }

    final Map<String, dynamic> orderJson =
        jsonDecode(orderRes.body) as Map<String, dynamic>;

    final filesRes = await clinicalService.listOrderFiles(widget.orderId);
    if (!mounted) return;

    if (filesRes.statusCode == 401) {
      setState(() => loading = false);
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (filesRes.statusCode == 403) {
      setState(() => loading = false);
      showAppSnackBar(context, "لا تملك الصلاحية لعرض ملفات هذا الطلب.");
      return;
    }
    if (filesRes.statusCode != 200) {
      setState(() => loading = false);
      showAppSnackBar(context, "فشل تحميل الملفات (${filesRes.statusCode}).");
      return;
    }

    final decodedFiles = jsonDecode(filesRes.body);
    final List<Map<String, dynamic>> filesList =
        decodedFiles is List
            ? decodedFiles.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    setState(() {
      order = orderJson;
      files = filesList;
      loading = false;
    });
  }

  // ----------- Helpers -----------

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

  /// Backend قد يرجع pending بدل pending_review - نطبّعها حسب سياسة Phase D.
  String _normalizedReviewStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "pending" || v == "pending_review" || v == "pending-review") {
      return "pending_review";
    }
    if (v == "approved") return "approved";
    if (v == "rejected") return "rejected";
    return raw;
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
    int pending = 0;
    int approved = 0;
    int rejected = 0;

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
      showAppSnackBar(context, "رابط غير صالح.");
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(context, "تعذر فتح الرابط. انسخه وافتحه يدويًا.");
    }
  }

  Future<bool> _confirmDecision({required String actionLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("تأكيد القرار"),
          content: Text(
            "هل أنت متأكد؟ لا يمكن التراجع.\nالإجراء: $actionLabel",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("تأكيد"),
            ),
          ],
        );
      },
    );
    return result == true;
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
      showAppSnackBar(context, "تمت الموافقة.");
      await loadAll();
      return;
    }
    if (res.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (res.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لمراجعة هذا الملف.");
      return;
    }
    showAppSnackBar(context, "فشل العملية (${res.statusCode}).");
  }

  Future<void> _rejectFile(int fileId) async {
    final note = await _askRejectNote();
    if (!mounted) return;
    if (note == null) return;

    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      showAppSnackBar(context, "ملاحظة الرفض مطلوبة.");
      return;
    }

    final confirmed = await _confirmDecision(actionLabel: "Reject");
    if (!mounted) return;
    if (!confirmed) return;

    final res = await clinicalService.rejectFile(fileId, doctorNote: trimmed);
    if (!mounted) return;

    if (res.statusCode == 200) {
      showAppSnackBar(context, "تم الرفض.");
      await loadAll();
      return;
    }
    if (res.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (res.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لمراجعة هذا الملف.");
      return;
    }
    showAppSnackBar(context, "فشل العملية (${res.statusCode}).");
  }

  // ----------- UI -----------

  @override
  Widget build(BuildContext context) {
    final o = order;
    final summary = _filesSummary();

    final orderTitle = o?["title"]?.toString().trim() ?? "";
    final doctorDisplayName =
        o?["doctor_display_name"]?.toString().trim().isNotEmpty == true
            ? o!["doctor_display_name"].toString().trim()
            : o?["doctor"]?.toString().trim();

    final doctorLabel =
        (doctorDisplayName != null && doctorDisplayName.trim().isNotEmpty)
            ? "د. $doctorDisplayName"
            : "";

    final categoryRaw = o?["order_category"]?.toString() ?? "";
    final orderIcon = _orderCategoryIcon(categoryRaw);

    return Scaffold(
      appBar: AppBar(
        // حسب طلبك: إخفاء رقم الطلب وكلمة "تفاصيل الطلب"
        title: const Text("تغاصيل الطلب "),
        actions: [
          IconButton(
            onPressed: () async {
              await loadAll();
              if (!mounted) return;
              showAppSnackBar(this.context, "تم التحديث.");
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
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
                          // صف العنوان + اسم الطبيب أقصى اليمين
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
                          Text("الحالة: ${o["status"]?.toString() ?? "open"}"),
                          Text(
                            "التاريخ: ${_formatDateTimeShort(o["created_at"]?.toString() ?? "")}",
                          ),
                          const SizedBox(height: 8),
                          if ((o["details"]?.toString() ?? "")
                              .trim()
                              .isNotEmpty)
                            Text(
                              "تعليمات/شروط: ${o["details"]?.toString() ?? ""}",
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
                            final rawUrl = f["file"]?.toString() ?? "";
                            final fileUrl = _resolveFileUrl(rawUrl);

                            final filename =
                                f["original_filename"]
                                            ?.toString()
                                            .trim()
                                            .isNotEmpty ==
                                        true
                                    ? f["original_filename"].toString()
                                    : rawUrl;

                            final normalizedStatus = _normalizedReviewStatus(
                              f["review_status"]?.toString() ?? "",
                            );

                            final doctorNote =
                                f["doctor_note"]?.toString() ?? "";

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
                                  // حسب طلبك: إخفاء الـ id ووضع أيقونة حسب نوع الطلب
                                  leading: CircleAvatar(child: Icon(orderIcon)),
                                  title: Text(
                                    filename.isNotEmpty ? filename : "ملف",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // حسب طلبك: إخفاء status: pending_review
                                  subtitle:
                                      doctorNote.trim().isNotEmpty
                                          ? Text(
                                            "ملاحظة الطبيب: $doctorNote",
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                          : null,
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
                                              context: this.context,
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

                                      // Review Policy (Doctor only) - بدون عرض status بالنص
                                      if (isDoctor) ...[
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
