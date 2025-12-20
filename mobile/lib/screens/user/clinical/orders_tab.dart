import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';
import 'order_details_screen.dart';

class OrdersTab extends StatefulWidget {
  final String role;
  final int userId;
  final int? selectedPatientId; // Phase D-2 (doctor context)

  const OrdersTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  late final ClinicalService clinicalService;
  Future<List<Map<String, dynamic>>>? ordersFuture;

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    ordersFuture = fetchOrders();
  }

  @override
  void didUpdateWidget(covariant OrdersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPatientId != widget.selectedPatientId) {
      reload();
    }
  }

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

  IconData _categoryIcon(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "lab_test") return Icons.science_outlined;
    if (v == "medical_imaging") return Icons.image_outlined;
    return Icons.description_outlined;
  }

  Future<List<Map<String, dynamic>>> fetchOrders() async {
    final response = await clinicalService.listOrders();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      final selectedPid = widget.selectedPatientId;
      List<Map<String, dynamic>> filtered = list;

      if (widget.role == "doctor" && selectedPid != null) {
        filtered =
            list.where((o) {
              final pid = _asInt(o["patient"]);
              return pid == selectedPid;
            }).toList();
      }

      // ترتيب الأحدث أولًا
      filtered.sort((a, b) {
        final da = _parseDate((a["created_at"] ?? "").toString());
        final db = _parseDate((b["created_at"] ?? "").toString());
        return db.compareTo(da);
      });

      return filtered;
    }

    if (response.statusCode == 401) {
      throw _HttpException(401, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
    }

    if (response.statusCode == 403) {
      throw _HttpException(403, "لا تملك الصلاحية لعرض الطلبات.");
    }

    try {
      final body = jsonDecode(response.body);
      final detail =
          body is Map && body["detail"] != null
              ? body["detail"].toString()
              : null;
      throw _HttpException(response.statusCode, detail ?? "حدث خطأ غير متوقع.");
    } catch (_) {
      throw _HttpException(response.statusCode, "حدث خطأ غير متوقع.");
    }
  }

  Future<void> reload() async {
    setState(() {
      ordersFuture = fetchOrders();
    });
  }

  Future<void> createOrderFlow() async {
    if (!isDoctor) {
      showAppSnackBar(context, "هذه العملية متاحة للطبيب فقط.");
      return;
    }

    final payload = await showDialog<_CreateOrderPayload>(
      context: context,
      builder: (_) => const _CreateOrderDialog(),
    );

    if (!mounted) return;
    if (payload == null) return;

    final response = await clinicalService.createOrder(
      doctorId: widget.userId,
      patientId: payload.patientId,
      orderCategory: payload.orderCategory,
      title: payload.title,
      details: payload.details,
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      showAppSnackBar(context, "تم إنشاء الطلب بنجاح.");
      await reload();
      return;
    }

    if (response.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }

    if (response.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لإنشاء طلب.");
      return;
    }

    try {
      final decoded = jsonDecode(response.body);
      final detail =
          decoded is Map && decoded["detail"] != null
              ? decoded["detail"].toString()
              : null;
      showAppSnackBar(
        context,
        detail ?? "فشل إنشاء الطلب (${response.statusCode}).",
      );
    } catch (_) {
      showAppSnackBar(context, "فشل إنشاء الطلب (${response.statusCode}).");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isDoctor)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async => createOrderFlow(),
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

              if (snapshot.hasError) {
                final err = snapshot.error;
                String message = "حدث خطأ.";
                if (err is _HttpException) message = err.message;

                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40),
                        const SizedBox(height: 12),
                        Text(message, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await reload();
                            if (!mounted) return;
                            showAppSnackBar(
                              this.context,
                              "تمت إعادة المحاولة.",
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text("إعادة المحاولة"),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final orders = snapshot.data ?? [];

              if (orders.isEmpty) {
                return const Center(child: Text("لا توجد طلبات حتى الآن."));
              }

              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final o = orders[index];
                    final oid = _asInt(o["id"]);
                    final title = o["title"]?.toString() ?? "طلب بدون عنوان";
                    final doctorName =
                        o["doctor_display_name"]?.toString() ?? "";
                    final createdAtRaw = o["created_at"]?.toString() ?? "";
                    final createdAt =
                        createdAtRaw.isNotEmpty
                            ? _formatDateShort(createdAtRaw)
                            : "";

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            _categoryIcon(
                              o["order_category"]?.toString() ?? "",
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(title)),
                            if (doctorName.isNotEmpty)
                              Text(
                                "د. $doctorName",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        subtitle: createdAt.isNotEmpty ? Text(createdAt) : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (oid == null) {
                            showAppSnackBar(this.context, "Invalid order id.");
                            return;
                          }
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder:
                                  (_) => OrderDetailsScreen(
                                    role: widget.role,
                                    orderId: oid,
                                  ),
                            ),
                          );
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

class _HttpException implements Exception {
  final int statusCode;
  final String message;

  _HttpException(this.statusCode, this.message);

  @override
  String toString() => "HTTP $statusCode: $message";
}

class _CreateOrderPayload {
  final int patientId;
  final String orderCategory;
  final String title;
  final String details;

  _CreateOrderPayload({
    required this.patientId,
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
  final TextEditingController patientIdController = TextEditingController();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  String orderCategory = "lab_test";

  @override
  void dispose() {
    patientIdController.dispose();
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
              TextField(
                controller: patientIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Patient ID",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
                  labelText: "Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Instructions / Conditions (اختياري)",
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
            final pid = int.tryParse(patientIdController.text.trim());
            if (pid == null || pid <= 0) {
              showAppSnackBar(context, "Patient ID غير صالح.");
              return;
            }

            final title = titleController.text.trim();
            if (title.isEmpty) {
              showAppSnackBar(context, "Title مطلوب.");
              return;
            }

            Navigator.pop(
              context,
              _CreateOrderPayload(
                patientId: pid,
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
