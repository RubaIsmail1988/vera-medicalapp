import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

class FilesTab extends StatefulWidget {
  final String role;
  final int userId;
  final int? selectedPatientId; // Phase D-2

  const FilesTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  late final ClinicalService clinicalService;

  bool loadingOrders = true;
  bool loadingFiles = false;
  bool uploading = false;

  List<Map<String, dynamic>> orders = [];
  int? selectedOrderId;

  List<Map<String, dynamic>> orderFiles = [];

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    loadOrders();
  }

  @override
  void didUpdateWidget(covariant FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedPatientId != widget.selectedPatientId) {
      setState(() {
        selectedOrderId = null;
        orderFiles = [];
      });
      loadOrders();
    }
  }

  bool get isPatient => widget.role == "patient";
  bool get isDoctor => widget.role == "doctor";

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  DateTime _parseDate(String s) {
    final dt = DateTime.tryParse(s);
    return dt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDateShort(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return "$dd/$mm/$yyyy – $hh:$mi";
  }

  String _categoryLabelShort(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return "تحليل";
    if (v == "medical_imaging") return "صورة";
    return raw;
  }

  IconData _categoryIcon(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return Icons.science_outlined; // 🧪
    if (v == "medical_imaging") return Icons.medical_services_outlined; // 🩻
    return Icons.description_outlined;
  }

  String _doctorName(Map<String, dynamic> o) {
    final n = o["doctor_display_name"]?.toString().trim();
    if (n != null && n.isNotEmpty) return "د. $n";

    final id = o["doctor"]?.toString().trim();
    if (id != null && id.isNotEmpty) return "د. $id";

    return "";
  }

  String _selectedOrderCategoryRaw() {
    final oid = selectedOrderId;
    if (oid == null) return "";

    final match = orders.where((o) => _asInt(o["id"]) == oid);
    if (match.isEmpty) return "";
    return match.first["order_category"]?.toString().trim() ?? "";
  }

  IconData _categoryIconForSelectedOrder() {
    final raw = _selectedOrderCategoryRaw();
    return _categoryIcon(raw);
  }

  Future<void> loadOrders() async {
    setState(() => loadingOrders = true);

    final res = await clinicalService.listOrders();
    if (!mounted) return;

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      // Doctor context: فلترة حسب المريض المختار
      final selectedPid = widget.selectedPatientId;
      List<Map<String, dynamic>> filtered = list;

      if (widget.role == "doctor" && selectedPid != null) {
        filtered =
            list.where((o) {
              final pid = _asInt(o["patient"]);
              return pid == selectedPid;
            }).toList();
      }

      // ترتيب الأحدث أولاً (يساعد dropdown)
      filtered.sort((a, b) {
        final da = _parseDate((a["created_at"] ?? "").toString());
        final db = _parseDate((b["created_at"] ?? "").toString());
        return db.compareTo(da);
      });

      setState(() {
        orders = filtered;
        loadingOrders = false;
      });
      return;
    }

    setState(() => loadingOrders = false);

    if (res.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (res.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لعرض الطلبات.");
      return;
    }

    showAppSnackBar(context, "فشل تحميل الطلبات (${res.statusCode}).");
  }

  Future<void> loadFilesForSelectedOrder() async {
    final oid = selectedOrderId;
    if (oid == null) {
      setState(() => orderFiles = []);
      return;
    }

    setState(() => loadingFiles = true);

    final res = await clinicalService.listOrderFiles(oid);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      setState(() {
        orderFiles = list;
        loadingFiles = false;
      });
      return;
    }

    setState(() => loadingFiles = false);

    if (res.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }
    if (res.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لعرض ملفات هذا الطلب.");
      return;
    }

    showAppSnackBar(context, "فشل تحميل الملفات (${res.statusCode}).");
  }

  // ---------- Policy helpers (pending_review / approved / rejected) ----------

  String normalizedReviewStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "pending" || v == "pending_review" || v == "pending-review") {
      return "pending_review";
    }
    if (v == "approved") return "approved";
    if (v == "rejected") return "rejected";
    return raw;
  }

  Map<String, dynamic>? latestFile() {
    if (orderFiles.isEmpty) return null;

    final sorted = [...orderFiles];
    sorted.sort((a, b) {
      final aTime = a["uploaded_at"]?.toString() ?? "";
      final bTime = b["uploaded_at"]?.toString() ?? "";
      if (aTime.isNotEmpty && bTime.isNotEmpty) {
        return bTime.compareTo(aTime);
      }
      final aId = int.tryParse(a["id"]?.toString() ?? "") ?? 0;
      final bId = int.tryParse(b["id"]?.toString() ?? "") ?? 0;
      return bId.compareTo(aId);
    });

    return sorted.first;
  }

  bool get canUploadForPatient {
    if (!isPatient) return false;
    if (selectedOrderId == null) return false;

    final last = latestFile();
    if (last == null) return true;

    final status = normalizedReviewStatus(
      last["review_status"]?.toString() ?? "",
    );
    if (status == "pending_review") return false;
    if (status == "approved") return false;
    if (status == "rejected") return true;
    return false;
  }

  // ---------- Upload (Web) ----------

  bool _isAllowedExtension(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".pdf");
  }

  Future<void> pickAndUpload() async {
    if (!canUploadForPatient) {
      return; // بدون رسائل إضافية (حسب طلبك)
    }

    final oid = selectedOrderId;
    if (oid == null) return;

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ["jpg", "jpeg", "png", "pdf"],
    );

    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final filename = file.name.trim();

    final Uint8List? bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showAppSnackBar(context, "تعذر قراءة الملف.");
      return;
    }

    if (!_isAllowedExtension(filename)) {
      showAppSnackBar(
        context,
        "صيغة الملف غير مدعومة. المسموح: jpg/jpeg/png/pdf.",
      );
      return;
    }

    setState(() => uploading = true);

    final streamed = await clinicalService.uploadFileToOrderBytes(
      orderId: oid,
      bytes: bytes,
      filename: filename,
    );

    if (!mounted) return;

    setState(() => uploading = false);

    final statusCode = streamed.statusCode;
    final bodyText = await streamed.stream.bytesToString();

    if (!mounted) return;

    if (statusCode == 201) {
      showAppSnackBar(context, "تم رفع الملف بنجاح.");
      await loadFilesForSelectedOrder();
      return;
    }

    if (statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }

    if (statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لرفع ملف لهذا الطلب.");
      return;
    }

    try {
      final decoded = jsonDecode(bodyText);
      final detail =
          decoded is Map && decoded["detail"] != null
              ? decoded["detail"].toString()
              : null;
      showAppSnackBar(context, detail ?? "فشل رفع الملف ($statusCode).");
    } catch (_) {
      showAppSnackBar(context, "فشل رفع الملف ($statusCode).");
    }
  }

  // ---------- UI ----------

  // المطلوب: نوع الطلب + اسم الطلب + تاريخ الطلب + اسم الطبيب
  String orderTitle(Map<String, dynamic> o) {
    final title = o["title"]?.toString().trim() ?? "";
    final categoryRaw = o["order_category"]?.toString().trim() ?? "";
    final createdAt = o["created_at"]?.toString().trim() ?? "";

    final typeLabel = _categoryLabelShort(categoryRaw);
    final createdShort =
        createdAt.isNotEmpty ? _formatDateShort(createdAt) : "";
    final doctor = _doctorName(o);

    final safeTitle = title.isNotEmpty ? title : "طلب";
    final parts = <String>[
      if (typeLabel.isNotEmpty) typeLabel,
      safeTitle,
      if (createdShort.isNotEmpty) createdShort,
      if (doctor.isNotEmpty) doctor,
    ];

    return parts.join(" • ");
  }

  @override
  Widget build(BuildContext context) {
    final bool hasOrders = orders.isNotEmpty;
    final bool canInteractWithDropdown = !loadingOrders && hasOrders;
    final bool uploadEnabled = canUploadForPatient && !uploading;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (loadingOrders)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            DropdownButtonFormField<int>(
              isExpanded: true,
              menuMaxHeight: 320,
              value: selectedOrderId,
              decoration: const InputDecoration(
                labelText: "اختر طلبًا طبيًا",
                border: OutlineInputBorder(),
              ),
              items:
                  orders
                      .map((o) {
                        final id = int.tryParse(o["id"]?.toString() ?? "");
                        if (id == null) return null;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            orderTitle(o),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      })
                      .whereType<DropdownMenuItem<int>>()
                      .toList(),
              onChanged:
                  canInteractWithDropdown
                      ? (value) async {
                        setState(() {
                          selectedOrderId = value;
                          orderFiles = [];
                        });
                        await loadFilesForSelectedOrder();
                      }
                      : null,
            ),

          const SizedBox(height: 12),

          if (isPatient)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploadEnabled ? () async => pickAndUpload() : null,
                icon:
                    uploading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upload_file),
                label: Text(
                  uploading ? "جارٍ الرفع..." : "رفع ملف (JPG/PNG/PDF)",
                ),
              ),
            ),

          const SizedBox(height: 12),

          Expanded(
            child:
                selectedOrderId == null
                    ? const Center(child: Text("اختر طلبًا لعرض ملفاته."))
                    : loadingFiles
                    ? const Center(child: CircularProgressIndicator())
                    : (orderFiles.isEmpty)
                    ? const Center(child: Text("لا توجد ملفات لهذا الطلب."))
                    : ListView.separated(
                      itemCount: orderFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final f = orderFiles[index];
                        final id = f["id"]?.toString() ?? "-";
                        final filename =
                            (f["original_filename"]
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true)
                                ? f["original_filename"].toString()
                                : (f["file"]?.toString() ?? "");

                        final status = normalizedReviewStatus(
                          f["review_status"]?.toString() ?? "",
                        );
                        final note = f["doctor_note"]?.toString() ?? "";

                        return Card(
                          child: ListTile(
                            // المطلوب: إزالة الـ id واستبداله بأيقونة حسب نوع الطلب المختار
                            leading: CircleAvatar(
                              child: Icon(_categoryIconForSelectedOrder()),
                            ),
                            title: Text(filename.isNotEmpty ? filename : "ملف"),
                            subtitle: Text(
                              "الحالة: $status${note.trim().isNotEmpty ? "\nملاحظة الطبيب: $note" : ""}",
                            ),
                            trailing:
                                (isPatient && status == "pending_review")
                                    ? IconButton(
                                      tooltip: "حذف الملف (Pending فقط)",
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed:
                                          uploading
                                              ? null
                                              : () async {
                                                final confirm = await showDialog<
                                                  bool
                                                >(
                                                  context: this.context,
                                                  builder: (ctx) {
                                                    return AlertDialog(
                                                      title: const Text(
                                                        "تأكيد الحذف",
                                                      ),
                                                      content: const Text(
                                                        "هل أنت متأكد من حذف هذا الملف؟\nسيتم حذف الملف نهائيًا.",
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                          child: const Text(
                                                            "إلغاء",
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          onPressed:
                                                              () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                          child: const Text(
                                                            "حذف",
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                );

                                                if (!mounted) return;
                                                if (confirm != true) return;

                                                final fileId = int.tryParse(id);
                                                if (fileId == null) {
                                                  showAppSnackBar(
                                                    this.context,
                                                    "File ID غير صالح.",
                                                  );
                                                  return;
                                                }

                                                setState(
                                                  () => uploading = true,
                                                );

                                                final res =
                                                    await clinicalService
                                                        .deleteMedicalFile(
                                                          fileId,
                                                        );

                                                if (!mounted) return;

                                                setState(
                                                  () => uploading = false,
                                                );

                                                if (res.statusCode == 204 ||
                                                    res.statusCode == 200) {
                                                  showAppSnackBar(
                                                    this.context,
                                                    "تم حذف الملف بنجاح.",
                                                  );
                                                  await loadFilesForSelectedOrder();
                                                  return;
                                                }

                                                if (res.statusCode == 401) {
                                                  showAppSnackBar(
                                                    this.context,
                                                    "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.",
                                                  );
                                                  return;
                                                }

                                                if (res.statusCode == 403) {
                                                  showAppSnackBar(
                                                    this.context,
                                                    "لا تملك الصلاحية لحذف هذا الملف (مسموح فقط للـ pending).",
                                                  );
                                                  return;
                                                }

                                                showAppSnackBar(
                                                  this.context,
                                                  "فشل حذف الملف (${res.statusCode}).",
                                                );
                                              },
                                    )
                                    : null,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
