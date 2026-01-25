import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

class OrdersTab extends StatefulWidget {
  final String role; // doctor | patient
  final int userId;

  /// doctor context: patient id (comes from UnifiedRecordScreen)
  final int? selectedPatientId;

  /// appointment context: appointment id (comes from UnifiedRecordScreen)
  final int? selectedAppointmentId;

  const OrdersTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
    this.selectedAppointmentId,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  late final ClinicalService clinicalService;
  Future<List<Map<String, dynamic>>>? ordersFuture;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  bool get hasApptFilter =>
      widget.selectedAppointmentId != null && widget.selectedAppointmentId! > 0;

  /// المطلوب: الطبيب لا يُنشئ طلبًا إلا ضمن سياق موعد
  bool get canDoctorCreateOrder => isDoctor && hasApptFilter;

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    ordersFuture = _fetchOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final pidChanged = oldWidget.selectedPatientId != widget.selectedPatientId;
    final apptChanged =
        oldWidget.selectedAppointmentId != widget.selectedAppointmentId;

    if (pidChanged || apptChanged) {
      _reload();
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  DateTime _parseCreatedAtOrMin(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
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

  IconData _categoryIcon(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return Icons.science_outlined;
    if (v == "medical_imaging") return Icons.medical_services_outlined;
    return Icons.description_outlined;
  }

  String _statusLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "open") return "مفتوح";
    if (v == "fulfilled") return "مكتمل";
    if (v == "cancelled") return "ملغي";
    return raw.trim().isEmpty ? "open" : raw;
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final response = await clinicalService.listOrders();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      final selectedPid = widget.selectedPatientId;
      final selectedApptId = widget.selectedAppointmentId;

      var filtered = list;

      // Doctor context: filter by selected patient
      if (isDoctor && selectedPid != null && selectedPid > 0) {
        filtered =
            filtered.where((o) {
              final pid = _asInt(o["patient"]);
              return pid == selectedPid;
            }).toList();
      }

      // Appointment context: filter by appointmentId (doctor & patient)
      if (selectedApptId != null && selectedApptId > 0) {
        filtered =
            filtered.where((o) {
              final appt = _asInt(o["appointment"]);
              return appt == selectedApptId;
            }).toList();
      }

      // newest first
      filtered.sort((a, b) {
        final aRaw = a["created_at"]?.toString() ?? "";
        final bRaw = b["created_at"]?.toString() ?? "";
        final ad = _parseCreatedAtOrMin(aRaw);
        final bd = _parseCreatedAtOrMin(bRaw);
        return bd.compareTo(ad);
      });

      return filtered;
    }

    // Fetch error: throw "mapped" message (يتم تحويله إلى Inline بالـ UI)
    Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    final message = mapHttpErrorToArabicMessage(
      statusCode: response.statusCode,
      data: body,
    );

    throw Exception(message);
  }

  Future<void> _reload() async {
    final future = _fetchOrders();
    if (!mounted) return;
    setState(() => ordersFuture = future);
    await future;
  }

  Future<void> _createOrderFlow() async {
    // Action guard (SnackBar مسموح)
    if (!isDoctor) {
      showAppSnackBar(
        context,
        "هذه العملية متاحة للطبيب فقط.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    final apptId = widget.selectedAppointmentId;
    if (apptId == null || apptId <= 0) {
      showAppSnackBar(
        context,
        "اختر موعدًا أولًا لإنشاء طلب مرتبط به.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    final payload = await showDialog<_CreateOrderPayload>(
      context: context,
      builder: (_) => const _CreateOrderDialog(),
    );

    if (!mounted) return;
    if (payload == null) return;

    final response = await clinicalService.createOrder(
      appointmentId: apptId,
      orderCategory: payload.orderCategory,
      title: payload.title,
      details: payload.details,
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      showAppSnackBar(
        context,
        "تم إنشاء الطلب بنجاح.",
        type: AppSnackBarType.success,
      );
      await _reload();
      return;
    }

    // Action error: SnackBar موحّد عبر ui_helpers
    Object? body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = response.body;
    }

    showApiErrorSnackBar(context, statusCode: response.statusCode, data: body);
  }

  String _buildQuery({int? patientId, int? appointmentId, String? role}) {
    final qp = <String, String>{};
    if (role != null && role.trim().isNotEmpty) qp["role"] = role.trim();
    if (patientId != null && patientId > 0) qp["patientId"] = "$patientId";
    if (appointmentId != null && appointmentId > 0) {
      qp["appointmentId"] = "$appointmentId";
    }
    if (qp.isEmpty) return "";
    return "?${Uri(queryParameters: qp).query}";
  }

  void _openOrderDetails(int orderId) {
    final pid = widget.selectedPatientId;
    final apptId = widget.selectedAppointmentId;

    if (isDoctor) {
      if (pid == null || pid <= 0) {
        showAppSnackBar(
          context,
          "اختر مريضًا أولًا.",
          type: AppSnackBarType.warning,
        );
        return;
      }
      final q = _buildQuery(
        role: widget.role,
        patientId: pid,
        appointmentId: apptId,
      );
      context.go("/app/record/orders/$orderId$q");
      return;
    }

    final q = _buildQuery(role: widget.role, appointmentId: apptId);
    context.go("/app/record/orders/$orderId$q");
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // المطلوب: لا نُظهر زر "إنشاء طلب" للطبيب إلا إذا كان هناك appointmentId
        if (canDoctorCreateOrder)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createOrderFlow,
                icon: const Icon(Icons.add),
                label: const Text("إنشاء طلب"),
              ),
            ),
          ),

        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Fetch error (Inline only)
              if (snapshot.hasError) {
                final mapped = mapFetchExceptionToInlineState(snapshot.error!);

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      AppInlineErrorState(
                        title: mapped.title,
                        message: mapped.message,
                        icon: mapped.icon,
                        onRetry: _reload,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              }

              final orders = snapshot.data ?? [];

              if (orders.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 140),
                      Center(
                        child: Text(
                          hasApptFilter
                              ? "لا توجد طلبات مرتبطة بهذا الموعد."
                              : "لا توجد طلبات حتى الآن.",
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final o = orders[index];

                    final oid = _asInt(o["id"]);
                    final title = (o["title"]?.toString() ?? "").trim();
                    final safeTitle =
                        title.isNotEmpty ? title : "طلب بدون عنوان";

                    final doctorName =
                        (o["doctor_display_name"]?.toString() ?? "").trim();

                    final createdAtRaw =
                        (o["created_at"]?.toString() ?? "").trim();
                    final createdAt =
                        createdAtRaw.isNotEmpty
                            ? _formatDateShort(createdAtRaw)
                            : "";

                    final statusRaw =
                        (o["status"]?.toString() ?? "open").trim();
                    final statusLabel = _statusLabel(statusRaw);

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            _categoryIcon(
                              o["order_category"]?.toString() ?? "",
                            ),
                          ),
                        ),
                        title: Text(
                          safeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (createdAt.isNotEmpty) Text(createdAt),
                            Text("الحالة: $statusLabel"),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (doctorName.isNotEmpty)
                              Text(
                                "د. $doctorName",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          if (oid == null) {
                            showAppSnackBar(
                              context,
                              "معرّف الطلب غير صالح.",
                              type: AppSnackBarType.error,
                            );
                            return;
                          }
                          _openOrderDetails(oid);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CreateOrderPayload {
  final String orderCategory;
  final String title;
  final String details;

  _CreateOrderPayload({
    required this.orderCategory,
    required this.title,
    required this.details,
  });
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog();

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  String orderCategory = "lab_test";

  @override
  void dispose() {
    titleController.dispose();
    detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("إنشاء طلب"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: orderCategory,
                decoration: const InputDecoration(
                  labelText: "نوع الطلب",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: "lab_test",
                    child: Text("تحاليل"),
                  ),
                  DropdownMenuItem<String>(
                    value: "medical_imaging",
                    child: Text("صور"),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => orderCategory = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "العنوان",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "تعليمات/شروط (اختياري)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("إلغاء"),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isEmpty) {
              showAppSnackBar(
                context,
                "العنوان مطلوب.",
                type: AppSnackBarType.warning,
              );
              return;
            }

            Navigator.pop(
              context,
              _CreateOrderPayload(
                orderCategory: orderCategory,
                title: title,
                details: detailsController.text.trim(),
              ),
            );
          },
          child: const Text("إنشاء"),
        ),
      ],
    );
  }
}
