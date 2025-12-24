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
  final int? selectedPatientId; // Phase D-2 (doctor context)

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

  String? ordersErrorMessage;
  String? filesErrorMessage;

  List<Map<String, dynamic>> orders = [];
  int? selectedOrderId;

  List<Map<String, dynamic>> orderFiles = [];

  bool get isPatient => widget.role == "patient";
  bool get isDoctor => widget.role == "doctor";

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    _loadOrders();
  }

  @override
  void didUpdateWidget(covariant FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedPatientId != widget.selectedPatientId) {
      setState(() {
        selectedOrderId = null;
        orderFiles = [];
        filesErrorMessage = null;
      });
      _loadOrders();
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing / formatting
  // ---------------------------------------------------------------------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  DateTime _parseDateOrMin(String s) {
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
    return _categoryIcon(_selectedOrderCategoryRaw());
  }

  // ---------------------------------------------------------------------------
  // Load orders / files
  // ---------------------------------------------------------------------------

  Future<void> _loadOrders() async {
    setState(() {
      loadingOrders = true;
      ordersErrorMessage = null;
    });

    final res = await clinicalService.listOrders();
    if (!mounted) return;

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      // Doctor context: filter by selected patient
      final selectedPid = widget.selectedPatientId;
      List<Map<String, dynamic>> filtered = list;

      if (isDoctor && selectedPid != null) {
        filtered =
            list.where((o) => _asInt(o["patient"]) == selectedPid).toList();
      }

      // newest first
      filtered.sort((a, b) {
        final da = _parseDateOrMin((a["created_at"] ?? "").toString());
        final db = _parseDateOrMin((b["created_at"] ?? "").toString());
        return db.compareTo(da);
      });

      setState(() {
        orders = filtered;
        loadingOrders = false;
      });

      return;
    }

    final message =
        (res.statusCode == 401)
            ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
            : (res.statusCode == 403)
            ? "لا تملك الصلاحية لعرض الطلبات."
            : "فشل تحميل الطلبات (${res.statusCode}).";

    setState(() {
      loadingOrders = false;
      ordersErrorMessage = message;
    });

    showAppSnackBar(context, message, type: AppSnackBarType.error);
  }

  Future<void> _loadFilesForSelectedOrder() async {
    final oid = selectedOrderId;
    if (oid == null) {
      setState(() {
        orderFiles = [];
        filesErrorMessage = null;
      });
      return;
    }

    setState(() {
      loadingFiles = true;
      filesErrorMessage = null;
    });

    final res = await clinicalService.listOrderFiles(oid);
    if (!mounted) return;

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      setState(() {
        orderFiles = list;
        loadingFiles = false;
      });
      return;
    }

    final message =
        (res.statusCode == 401)
            ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
            : (res.statusCode == 403)
            ? "لا تملك الصلاحية لعرض ملفات هذا الطلب."
            : "فشل تحميل الملفات (${res.statusCode}).";

    setState(() {
      loadingFiles = false;
      filesErrorMessage = message;
    });

    showAppSnackBar(context, message, type: AppSnackBarType.error);
  }

  // ---------------------------------------------------------------------------
  // Policy helpers (pending_review / approved / rejected)
  // ---------------------------------------------------------------------------

  String _normalizedReviewStatus(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "pending" || v == "pending_review" || v == "pending-review") {
      return "pending_review";
    }
    if (v == "approved") return "approved";
    if (v == "rejected") return "rejected";
    return v.isNotEmpty ? v : "pending_review";
  }

  String _reviewStatusLabel(String normalized) {
    switch (normalized) {
      case "pending_review":
        return "قيد المراجعة";
      case "approved":
        return "مقبول";
      case "rejected":
        return "مرفوض";
      default:
        return normalized;
    }
  }

  Map<String, dynamic>? _latestFile() {
    if (orderFiles.isEmpty) return null;

    final sorted = [...orderFiles];
    sorted.sort((a, b) {
      final aTime = a["uploaded_at"]?.toString() ?? "";
      final bTime = b["uploaded_at"]?.toString() ?? "";
      if (aTime.isNotEmpty && bTime.isNotEmpty) return bTime.compareTo(aTime);

      final aId = int.tryParse(a["id"]?.toString() ?? "") ?? 0;
      final bId = int.tryParse(b["id"]?.toString() ?? "") ?? 0;
      return bId.compareTo(aId);
    });

    return sorted.first;
  }

  bool get _canUploadForPatient {
    if (!isPatient) return false;
    if (selectedOrderId == null) return false;

    final last = _latestFile();
    if (last == null) return true;

    final status = _normalizedReviewStatus(
      last["review_status"]?.toString() ?? "",
    );
    if (status == "pending_review") return false;
    if (status == "approved") return false;
    if (status == "rejected") return true;

    return false;
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  bool _isAllowedExtension(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".pdf");
  }

  Future<void> _pickAndUpload() async {
    if (!_canUploadForPatient) {
      showAppSnackBar(
        context,
        "لا يمكن الرفع الآن. يوجد ملف قيد المراجعة أو تم اعتماد النتيجة.",
        type: AppSnackBarType.warning,
      );
      return;
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

    final picked = result.files.first;
    final filename = picked.name.trim();

    final Uint8List? bytes = picked.bytes;
    if (bytes == null || bytes.isEmpty) {
      showAppSnackBar(
        context,
        "تعذر قراءة الملف.",
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!_isAllowedExtension(filename)) {
      showAppSnackBar(
        context,
        "صيغة الملف غير مدعومة. المسموح: JPG / PNG / PDF.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => uploading = true);

    final streamed = await clinicalService.uploadFileToOrderBytes(
      orderId: oid,
      bytes: bytes,
      filename: filename,
    );

    final statusCode = streamed.statusCode;
    final bodyText = await streamed.stream.bytesToString();

    if (!mounted) return;
    setState(() => uploading = false);

    if (statusCode == 201) {
      showAppSnackBar(
        context,
        "تم رفع الملف بنجاح.",
        type: AppSnackBarType.success,
      );
      await _loadFilesForSelectedOrder();
      return;
    }

    if (statusCode == 401) {
      showAppSnackBar(
        context,
        "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.",
        type: AppSnackBarType.error,
      );
      return;
    }

    if (statusCode == 403) {
      showAppSnackBar(
        context,
        "لا تملك الصلاحية لرفع ملف لهذا الطلب.",
        type: AppSnackBarType.error,
      );
      return;
    }

    try {
      final decoded = jsonDecode(bodyText);
      final detail =
          (decoded is Map && decoded["detail"] != null)
              ? decoded["detail"].toString()
              : null;
      showAppSnackBar(
        context,
        detail ?? "فشل رفع الملف ($statusCode).",
        type: AppSnackBarType.error,
      );
    } catch (_) {
      showAppSnackBar(
        context,
        "فشل رفع الملف ($statusCode).",
        type: AppSnackBarType.error,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Delete (patient, pending only)
  // ---------------------------------------------------------------------------

  Future<void> _deleteFile(int fileId) async {
    if (!isPatient) return;

    final ok = await showConfirmDialog(
      context,
      title: "تأكيد الحذف",
      message: "هل أنت متأكد من حذف هذا الملف؟\nسيتم حذف الملف نهائيًا.",
      confirmText: "حذف",
      cancelText: "إلغاء",
      danger: true,
    );

    if (!mounted) return;
    if (!ok) return;

    setState(() => uploading = true);

    final res = await clinicalService.deleteMedicalFile(fileId);

    if (!mounted) return;
    setState(() => uploading = false);

    if (res.statusCode == 204 || res.statusCode == 200) {
      showAppSnackBar(
        context,
        "تم حذف الملف بنجاح.",
        type: AppSnackBarType.success,
      );
      await _loadFilesForSelectedOrder();
      return;
    }

    if (res.statusCode == 401) {
      showAppSnackBar(
        context,
        "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.",
        type: AppSnackBarType.error,
      );
      return;
    }

    if (res.statusCode == 403) {
      showAppSnackBar(
        context,
        "لا تملك الصلاحية لحذف هذا الملف (مسموح فقط عندما يكون قيد المراجعة).",
        type: AppSnackBarType.error,
      );
      return;
    }

    showAppSnackBar(
      context,
      "فشل حذف الملف (${res.statusCode}).",
      type: AppSnackBarType.error,
    );
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  String _orderTitle(Map<String, dynamic> o) {
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

  Widget _stateView({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final hasOrders = orders.isNotEmpty;
    final canInteractWithDropdown = !loadingOrders && hasOrders;
    final uploadEnabled = _canUploadForPatient && !uploading;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Orders dropdown / state
          if (loadingOrders)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (ordersErrorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(ordersErrorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _loadOrders(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("إعادة المحاولة"),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (!hasOrders)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  isDoctor
                      ? "لا توجد طلبات لهذا المريض."
                      : "لا توجد طلبات طبية حتى الآن.",
                  textAlign: TextAlign.center,
                ),
              ),
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
                            _orderTitle(o),
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
                          filesErrorMessage = null;
                        });
                        await _loadFilesForSelectedOrder();
                      }
                      : null,
            ),

          const SizedBox(height: 12),

          // Upload button (patient only)
          if (isPatient)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: uploadEnabled ? _pickAndUpload : null,
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

          // Files list / state
          Expanded(
            child:
                selectedOrderId == null
                    ? _stateView(
                      icon: Icons.info_outline,
                      title: "اختر طلبًا",
                      message: "اختر طلبًا من الأعلى لعرض ملفاته.",
                    )
                    : loadingFiles
                    ? const Center(child: CircularProgressIndicator())
                    : (filesErrorMessage != null)
                    ? _stateView(
                      icon: Icons.error_outline,
                      title: "تعذر تحميل الملفات",
                      message: filesErrorMessage!,
                      action: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadFilesForSelectedOrder,
                          icon: const Icon(Icons.refresh),
                          label: const Text("إعادة المحاولة"),
                        ),
                      ),
                    )
                    : orderFiles.isEmpty
                    ? _stateView(
                      icon: Icons.folder_off_outlined,
                      title: "لا توجد ملفات",
                      message: "لا توجد ملفات مرفوعة لهذا الطلب.",
                    )
                    : ListView.separated(
                      itemCount: orderFiles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final f = orderFiles[index];

                        final fileId = int.tryParse(f["id"]?.toString() ?? "");
                        final filename =
                            (f["original_filename"]
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ==
                                    true)
                                ? f["original_filename"].toString()
                                : (f["file"]?.toString() ?? "");

                        final statusNorm = _normalizedReviewStatus(
                          f["review_status"]?.toString() ?? "",
                        );
                        final statusLabel = _reviewStatusLabel(statusNorm);

                        final note =
                            (f["doctor_note"]?.toString() ?? "").trim();

                        final canDelete =
                            isPatient &&
                            statusNorm == "pending_review" &&
                            fileId != null &&
                            !uploading;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(_categoryIconForSelectedOrder()),
                            ),
                            title: Text(filename.isNotEmpty ? filename : "ملف"),
                            subtitle: Text(
                              "الحالة: $statusLabel${note.isNotEmpty ? "\nملاحظة الطبيب: $note" : ""}",
                            ),
                            trailing:
                                canDelete
                                    ? IconButton(
                                      tooltip: "حذف الملف (قيد المراجعة فقط)",
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await _deleteFile(fileId);
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
