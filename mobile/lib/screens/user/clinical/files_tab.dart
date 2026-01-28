// mobile/lib/screens/user/clinical/files_tab.dart
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
  final int? selectedPatientId; // doctor context
  final int? selectedAppointmentId; // appointment context

  const FilesTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
    this.selectedAppointmentId,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  late final ClinicalService clinicalService;

  Future<List<Map<String, dynamic>>>? ordersFuture;
  Future<List<Map<String, dynamic>>>? filesFuture;

  bool uploading = false;

  List<Map<String, dynamic>> lastOrders = [];
  int? selectedOrderId;

  bool get isPatient => widget.role == "patient";
  bool get isDoctor => widget.role == "doctor";

  bool get hasAppointmentFilter {
    final apptId = widget.selectedAppointmentId;
    return apptId != null && apptId > 0;
  }

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    ordersFuture = _fetchOrders();
  }

  @override
  void didUpdateWidget(covariant FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final patientChanged =
        oldWidget.selectedPatientId != widget.selectedPatientId;
    final apptChanged =
        oldWidget.selectedAppointmentId != widget.selectedAppointmentId;

    if (patientChanged || apptChanged) {
      selectedOrderId = null;
      filesFuture = null;
      ordersFuture = _fetchOrders();
      if (mounted) setState(() {});
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
    return raw.trim();
  }

  IconData _categoryIcon(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return Icons.science_outlined;
    if (v == "medical_imaging") return Icons.medical_services_outlined;
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

    final match = lastOrders.where((o) => _asInt(o["id"]) == oid);
    if (match.isEmpty) return "";
    return match.first["order_category"]?.toString().trim() ?? "";
  }

  IconData _categoryIconForSelectedOrder() {
    return _categoryIcon(_selectedOrderCategoryRaw());
  }

  // ---------------------------------------------------------------------------
  // Fetch (orders / files) -- NO SnackBar
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final res = await clinicalService.listOrders();

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      final selectedPid = widget.selectedPatientId;
      final apptId = widget.selectedAppointmentId;

      var filtered = list;

      if (isDoctor && selectedPid != null && selectedPid > 0) {
        filtered =
            filtered.where((o) => _asInt(o["patient"]) == selectedPid).toList();
      }

      if (apptId != null && apptId > 0) {
        filtered =
            filtered.where((o) => _asInt(o["appointment"]) == apptId).toList();
      }

      filtered.sort((a, b) {
        final da = _parseDateOrMin((a["created_at"] ?? "").toString());
        final db = _parseDateOrMin((b["created_at"] ?? "").toString());
        return db.compareTo(da);
      });

      return filtered;
    }

    Object? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = res.body;
    }

    final message = mapHttpErrorToArabicMessage(
      statusCode: res.statusCode,
      data: body,
    );

    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> _fetchFiles(int orderId) async {
    final res = await clinicalService.listOrderFiles(orderId);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      return list;
    }

    Object? body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      body = res.body;
    }

    final message = mapHttpErrorToArabicMessage(
      statusCode: res.statusCode,
      data: body,
    );

    throw Exception(message);
  }

  Future<void> _reloadOrders() async {
    final future = _fetchOrders();
    if (!mounted) return;
    setState(() => ordersFuture = future);

    final list = await future;
    if (!mounted) return;

    lastOrders = list;

    final currentSelected = selectedOrderId;
    final stillExists =
        currentSelected != null &&
        list.any((o) => _asInt(o["id"]) == currentSelected);

    if (!stillExists) {
      setState(() {
        selectedOrderId = null;
        filesFuture = null;
      });
    }
  }

  Future<void> _reloadFiles() async {
    final oid = selectedOrderId;
    if (oid == null) return;

    final future = _fetchFiles(oid);
    if (!mounted) return;
    setState(() => filesFuture = future);
    await future;
  }

  Future<void> _selectOrderAndLoadFiles(int? orderId) async {
    if (!mounted) return;

    if (orderId == null) {
      setState(() {
        selectedOrderId = null;
        filesFuture = null;
      });
      return;
    }

    final future = _fetchFiles(orderId);
    setState(() {
      selectedOrderId = orderId;
      filesFuture = future;
    });

    await future;
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

  Map<String, dynamic>? _latestFileFrom(List<Map<String, dynamic>> files) {
    if (files.isEmpty) return null;

    final sorted = [...files];
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

  bool _canUploadForPatientWithFiles(List<Map<String, dynamic>> files) {
    if (!isPatient) return false;
    if (selectedOrderId == null) return false;

    final last = _latestFileFrom(files);
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
  // Upload (Action) -- SnackBar allowed
  // ---------------------------------------------------------------------------

  bool _isAllowedExtension(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".pdf");
  }

  Future<void> _pickAndUpload(List<Map<String, dynamic>> currentFiles) async {
    if (!_canUploadForPatientWithFiles(currentFiles)) {
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

    try {
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
        _reloadFiles();
        return;
      }

      Object? body;
      try {
        body = jsonDecode(bodyText);
      } catch (_) {
        body = bodyText;
      }

      showApiErrorSnackBar(context, statusCode: statusCode, data: body);
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل رفع الملف.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Delete (Action) -- SnackBar allowed
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

    try {
      final res = await clinicalService.deleteMedicalFile(fileId);

      if (!mounted) return;
      setState(() => uploading = false);

      if (res.statusCode == 204 || res.statusCode == 200) {
        showAppSnackBar(
          context,
          "تم حذف الملف بنجاح.",
          type: AppSnackBarType.success,
        );
        _reloadFiles();
        return;
      }

      Object? body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        body = res.body;
      }

      showApiErrorSnackBar(context, statusCode: res.statusCode, data: body);
    } catch (e) {
      if (!mounted) return;
      setState(() => uploading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل حذف الملف.',
      );
    }
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final emptyOrdersMessage =
        isDoctor
            ? (hasAppointmentFilter
                ? "لا توجد طلبات لهذا المريض ضمن هذا الموعد."
                : "لا توجد طلبات لهذا المريض.")
            : (hasAppointmentFilter
                ? "لا توجد طلبات مرتبطة بهذا الموعد."
                : "لا توجد طلبات طبية حتى الآن.");

    return Padding(
      padding: const EdgeInsets.all(12),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: ordersFuture,
        builder: (context, snapshot) {
          // 1) Loading: لا نعرض القسم السفلي إطلاقًا
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            Future<void> reloadFiles() async {
              final oid = selectedOrderId;
              if (oid == null) return;
              final future = _fetchFiles(oid);
              if (!mounted) return;
              setState(() => filesFuture = future);
              await future;
            }

            final mapped = mapFetchExceptionToInlineState(snapshot.error!);

            return RefreshIndicator(
              onRefresh: reloadFiles,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  AppInlineErrorState(
                    title: mapped.title,
                    message: mapped.message,
                    icon: mapped.icon,
                    onRetry: reloadFiles,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          final list = snapshot.data ?? [];
          lastOrders = list;

          // 3) Empty orders
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reloadOrders,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 140),
                  Center(child: Text(emptyOrdersMessage)),
                ],
              ),
            );
          }

          // 4) Orders exist: Dropdown + files area
          final canInteract = !uploading;

          return Column(
            children: [
              DropdownButtonFormField<int>(
                isExpanded: true,
                menuMaxHeight: 320,
                value: selectedOrderId,
                decoration: const InputDecoration(
                  labelText: "اختر طلبًا طبيًا",
                  border: OutlineInputBorder(),
                ),
                items:
                    list
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
                onChanged: canInteract ? _selectOrderAndLoadFiles : null,
              ),

              const SizedBox(height: 12),

              Expanded(
                child:
                    selectedOrderId == null
                        ? const Center(
                          child: Text("اختر طلبًا من الأعلى لعرض ملفاته."),
                        )
                        : FutureBuilder<List<Map<String, dynamic>>>(
                          future: filesFuture,
                          builder: (context, fileSnap) {
                            // عند أول اختيار: filesFuture قد تكون null لحظة واحدة
                            if (filesFuture == null ||
                                fileSnap.connectionState ==
                                    ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            if (fileSnap.hasError) {
                              final mapped = mapFetchExceptionToInlineState(
                                fileSnap.error!,
                              );

                              return RefreshIndicator(
                                onRefresh: _reloadFiles,
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    AppInlineErrorState(
                                      title: mapped.title,
                                      message: mapped.message,
                                      icon: mapped.icon,
                                      onRetry: _reloadFiles,
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              );
                            }

                            final files = fileSnap.data ?? [];
                            final uploadEnabled =
                                isPatient &&
                                !uploading &&
                                _canUploadForPatientWithFiles(files);

                            return Column(
                              children: [
                                if (isPatient)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          uploadEnabled
                                              ? () => _pickAndUpload(files)
                                              : null,
                                      icon:
                                          uploading
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Icon(Icons.upload_file),
                                      label: Text(
                                        uploading
                                            ? "جارٍ الرفع..."
                                            : "رفع ملف (JPG/PNG/PDF)",
                                      ),
                                    ),
                                  ),
                                if (isPatient) const SizedBox(height: 12),

                                Expanded(
                                  child:
                                      files.isEmpty
                                          ? RefreshIndicator(
                                            onRefresh: _reloadFiles,
                                            child: ListView(
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              children: const [
                                                SizedBox(height: 140),
                                                Center(
                                                  child: Text(
                                                    "لا توجد ملفات مرفوعة لهذا الطلب.",
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : RefreshIndicator(
                                            onRefresh: _reloadFiles,
                                            child: ListView.separated(
                                              physics:
                                                  const AlwaysScrollableScrollPhysics(),
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              itemCount: files.length,
                                              separatorBuilder:
                                                  (_, __) =>
                                                      const SizedBox(height: 8),
                                              itemBuilder: (context, index) {
                                                final f = files[index];

                                                final fileId = int.tryParse(
                                                  f["id"]?.toString() ?? "",
                                                );

                                                final original =
                                                    (f["original_filename"]
                                                                ?.toString()
                                                                .trim()
                                                                .isNotEmpty ==
                                                            true)
                                                        ? f["original_filename"]
                                                            .toString()
                                                        : "";

                                                final fallbackName =
                                                    (f["file"]?.toString() ??
                                                        "");

                                                final filename =
                                                    original.isNotEmpty
                                                        ? original
                                                        : fallbackName;

                                                final statusNorm =
                                                    _normalizedReviewStatus(
                                                      f["review_status"]
                                                              ?.toString() ??
                                                          "",
                                                    );

                                                final statusLabel =
                                                    _reviewStatusLabel(
                                                      statusNorm,
                                                    );

                                                final note =
                                                    (f["doctor_note"]
                                                                ?.toString() ??
                                                            "")
                                                        .trim();

                                                final canDelete =
                                                    isPatient &&
                                                    !uploading &&
                                                    statusNorm ==
                                                        "pending_review" &&
                                                    fileId != null;

                                                return Card(
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      child: Icon(
                                                        _categoryIconForSelectedOrder(),
                                                      ),
                                                    ),
                                                    title: Text(
                                                      filename.isNotEmpty
                                                          ? filename
                                                          : "ملف",
                                                    ),
                                                    subtitle: Text(
                                                      "الحالة: $statusLabel"
                                                      "${note.isNotEmpty ? "\nملاحظة الطبيب: $note" : ""}",
                                                    ),
                                                    trailing:
                                                        canDelete
                                                            ? IconButton(
                                                              tooltip:
                                                                  "حذف الملف (قيد المراجعة فقط)",
                                                              icon: const Icon(
                                                                Icons
                                                                    .delete_outline,
                                                              ),
                                                              onPressed: () async {
                                                                await _deleteFile(
                                                                  fileId,
                                                                );
                                                              },
                                                            )
                                                            : null,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                ),
                              ],
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}
