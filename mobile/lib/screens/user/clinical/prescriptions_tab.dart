import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

class PrescriptionsTab extends StatefulWidget {
  final String role;
  final int userId;
  final int? selectedPatientId; // doctor context
  final int? selectedAppointmentId; // appointment context

  const PrescriptionsTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
    this.selectedAppointmentId,
  });

  @override
  State<PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<PrescriptionsTab> {
  late final ClinicalService clinicalService;

  Future<List<Map<String, dynamic>>>? prescriptionsFuture;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  bool get hasApptFilter =>
      widget.selectedAppointmentId != null && widget.selectedAppointmentId! > 0;

  /// المطلوب: الطبيب لا ينشئ وصفة إلا ضمن سياق موعد
  bool get canDoctorCreatePrescription => isDoctor && hasApptFilter;

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    prescriptionsFuture = _fetchPrescriptions();
  }

  @override
  void didUpdateWidget(covariant PrescriptionsTab oldWidget) {
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

  String _formatDateTime(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "";

    final dt = DateTime.tryParse(s);
    if (dt == null) return "";

    final local = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, "0");

    final dd = two(local.day);
    final mm = two(local.month);
    final yyyy = local.year.toString();
    final hh = two(local.hour);
    final mi = two(local.minute);

    return "$dd/$mm/$yyyy – $hh:$mi";
  }

  // ---------------------------------------------------------------------------
  // Fetch (NO SnackBar)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchPrescriptions() async {
    final response = await clinicalService.listPrescriptions();

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
            filtered.where((p) {
              final pid = _asInt(p["patient"]);
              return pid == selectedPid;
            }).toList();
      }

      // Appointment context: filter by appointmentId (doctor & patient)
      if (selectedApptId != null && selectedApptId > 0) {
        filtered =
            filtered.where((p) {
              final appt = _asInt(p["appointment"]);
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
    final future = _fetchPrescriptions();
    if (!mounted) return;
    setState(() => prescriptionsFuture = future);
    await future;
  }

  Future<Map<String, dynamic>> _fetchPrescriptionDetails(
    int prescriptionId,
  ) async {
    final response = await clinicalService.getPrescriptionDetails(
      prescriptionId,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    }

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

  // ---------------------------------------------------------------------------
  // Details dialog (Fetch inside dialog, NO SnackBar)
  // ---------------------------------------------------------------------------

  Future<void> _openPrescriptionDetailsDialog(
    int prescriptionId, {
    required String doctorDisplayName,
    String? createdAtRawFromList,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final future = _fetchPrescriptionDetails(prescriptionId);

        Widget labeledLine({required String label, required String value}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    style: Theme.of(ctx).textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Text(
                    value,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
              ],
            ),
          );
        }

        Widget itemCard(Map<String, dynamic> it) {
          final name = it["medicine_name"]?.toString().trim() ?? "";
          final dosage = it["dosage"]?.toString().trim() ?? "";
          final frequency = it["frequency"]?.toString().trim() ?? "";
          final startDateRaw = it["start_date"]?.toString().trim() ?? "";
          final endDateRaw = it["end_date"]?.toString().trim() ?? "";
          final instructions = it["instructions"]?.toString().trim() ?? "";

          final lines = <Widget>[];

          if (name.isNotEmpty) {
            lines.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  name,
                  style: Theme.of(ctx).textTheme.titleSmall,
                  textAlign: TextAlign.start,
                ),
              ),
            );
          }

          if (dosage.isNotEmpty) {
            lines.add(labeledLine(label: "الجرعة", value: dosage));
          }
          if (frequency.isNotEmpty) {
            lines.add(labeledLine(label: "عدد المرات", value: frequency));
          }
          if (startDateRaw.isNotEmpty) {
            lines.add(
              labeledLine(label: "تاريخ بدء الدواء", value: startDateRaw),
            );
          }
          if (endDateRaw.isNotEmpty) {
            lines.add(
              labeledLine(label: "تاريخ انتهاء الدواء", value: endDateRaw),
            );
          }
          if (instructions.isNotEmpty) {
            lines.add(labeledLine(label: "التعليمات", value: instructions));
          }

          if (lines.isEmpty) return const SizedBox.shrink();

          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines,
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Center(
            child: Text("تفاصيل وصفتك", textAlign: TextAlign.center),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: FutureBuilder<Map<String, dynamic>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  final mapped = mapFetchExceptionToInlineState(snap.error!);

                  return AppInlineErrorState(
                    title: mapped.title,
                    message: mapped.message,
                    icon: mapped.icon,
                    onRetry: () {
                      // إعادة فتح نفس الـ dialog على نفس التفاصيل
                      Navigator.pop(ctx);
                      // ignore: discarded_futures
                      _openPrescriptionDetailsDialog(
                        prescriptionId,
                        doctorDisplayName: doctorDisplayName,
                        createdAtRawFromList: createdAtRawFromList,
                      );
                    },
                  );
                }

                final data = snap.data ?? <String, dynamic>{};

                final items =
                    (data["items"] is List)
                        ? (data["items"] as List).cast<Map<String, dynamic>>()
                        : <Map<String, dynamic>>[];

                final createdAtRaw =
                    (createdAtRawFromList?.trim().isNotEmpty ?? false)
                        ? createdAtRawFromList!.trim()
                        : (data["created_at"]?.toString() ?? "");

                final createdAtFormatted =
                    createdAtRaw.isNotEmpty
                        ? _formatDateTime(createdAtRaw)
                        : "";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: labeledLine(
                          label: "تاريخ الوصفة",
                          value:
                              createdAtFormatted.isNotEmpty
                                  ? createdAtFormatted
                                  : "-",
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child:
                          items.isEmpty
                              ? const Center(
                                child: Text("لا توجد تفاصيل متاحة."),
                              )
                              : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => itemCard(items[i]),
                              ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          "صادرة من الطبيب د. $doctorDisplayName",
                          style: Theme.of(ctx).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إغلاق"),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Create (Action) -- SnackBar allowed
  // ---------------------------------------------------------------------------

  Future<void> _createPrescriptionFlow() async {
    // حماية إضافية حتى لو الزر مخفي
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
        "اختر موعداً أولاً لإنشاء وصفة مرتبطة به.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    final payload = await showDialog<CreatePrescriptionPayload>(
      context: context,
      builder: (_) => const CreatePrescriptionDialog(),
    );

    if (!mounted) return;
    if (payload == null) return;

    try {
      final response = await clinicalService.createPrescription(
        appointmentId: apptId,
        notes: payload.notes,
        items: payload.items,
      );

      if (!mounted) return;

      final ok =
          response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;

      if (ok) {
        showAppSnackBar(
          context,
          "تم إنشاء الوصفة بنجاح.",
          type: AppSnackBarType.success,
        );
        _reload();
        return;
      }
      showApiErrorSnackBar(
        context,
        statusCode: response.statusCode,
        data: response.body,
      );
      return;
    } catch (e) {
      if (!mounted) return;
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل إنشاء الوصفة.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // المطلوب: لا نُظهر زر "إنشاء وصفة" للطبيب إلا ضمن سياق موعد
        if (canDoctorCreatePrescription)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _createPrescriptionFlow,
                icon: const Icon(Icons.add),
                label: const Text("إنشاء وصفة"),
              ),
            ),
          ),

        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: prescriptionsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

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
                    ],
                  ),
                );
              }

              final viewList = snapshot.data ?? [];

              if (viewList.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      const Icon(Icons.inbox_outlined, size: 40),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          hasApptFilter
                              ? "لا توجد وصفات مرتبطة بهذا الموعد."
                              : "لا توجد وصفات طبية مسجّلة حتى الآن",
                          textAlign: TextAlign.center,
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
                  itemCount: viewList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = viewList[index];

                    final idStr = p["id"]?.toString() ?? "";
                    final prescriptionId = int.tryParse(idStr);

                    final createdAtRaw = p["created_at"]?.toString() ?? "";
                    final createdAt = _formatDateTime(createdAtRaw);

                    final doctorDisplayNameRaw =
                        p["doctor_display_name"]?.toString().trim();
                    final doctorFallback = p["doctor"]?.toString().trim() ?? "";

                    final doctorDisplayName =
                        (doctorDisplayNameRaw != null &&
                                doctorDisplayNameRaw.isNotEmpty)
                            ? doctorDisplayNameRaw
                            : (doctorFallback.isNotEmpty
                                ? doctorFallback
                                : "-");

                    return Card(
                      child: ListTile(
                        title: Text(
                          "وصفة طبية صادرة من \nالطبيب: د. $doctorDisplayName",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            createdAt.isNotEmpty
                                ? "بتاريخ: $createdAt"
                                : "بتاريخ: -",
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: "عرض التفاصيل",
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () async {
                            if (prescriptionId == null) {
                              showAppSnackBar(
                                context,
                                "تعذر فتح التفاصيل.",
                                type: AppSnackBarType.error,
                              );
                              return;
                            }

                            await _openPrescriptionDetailsDialog(
                              prescriptionId,
                              doctorDisplayName: doctorDisplayName,
                              createdAtRawFromList: createdAtRaw,
                            );
                          },
                        ),
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

class CreatePrescriptionPayload {
  final String notes;
  final List<Map<String, dynamic>> items;

  CreatePrescriptionPayload({required this.notes, required this.items});
}

class CreatePrescriptionDialog extends StatefulWidget {
  const CreatePrescriptionDialog({super.key});

  @override
  State<CreatePrescriptionDialog> createState() =>
      CreatePrescriptionDialogState();
}

class CreatePrescriptionDialogState extends State<CreatePrescriptionDialog> {
  final TextEditingController notesController = TextEditingController();
  final List<Map<String, dynamic>> items = [];

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> _addItemDialog() async {
    final item = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const PrescriptionItemDialog(),
    );

    if (!mounted) return;
    if (item == null) return;

    setState(() {
      items.add(item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("إنشاء وصفة"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "ملاحظات (اختياري)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("الأدوية: ${items.length}")),
                  TextButton.icon(
                    onPressed: _addItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("إضافة دواء"),
                  ),
                ],
              ),
              if (items.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  width: double.maxFinite,
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final name = it["medicine_name"]?.toString() ?? "";
                      final dosage = it["dosage"]?.toString() ?? "";
                      final freq = it["frequency"]?.toString() ?? "";
                      final start = it["start_date"]?.toString() ?? "";
                      final endDate = it["end_date"]?.toString() ?? "";
                      final endLabel =
                          endDate.trim().isNotEmpty ? endDate : "-";

                      return ListTile(
                        title: Text(name.isNotEmpty ? name : "دواء"),
                        subtitle: Text(
                          [
                            if (dosage.trim().isNotEmpty) "الجرعة: $dosage",
                            if (freq.trim().isNotEmpty) "التردد: $freq",
                            if (start.trim().isNotEmpty) "البدء: $start",
                            "الانتهاء: $endLabel",
                          ].join("\n"),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() {
                              items.removeAt(i);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
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
            if (items.isEmpty) {
              showAppSnackBar(
                context,
                "أضف دواء واحد على الأقل.",
                type: AppSnackBarType.warning,
              );
              return;
            }

            Navigator.pop(
              context,
              CreatePrescriptionPayload(
                notes: notesController.text.trim(),
                items: items,
              ),
            );
          },
          child: const Text("إنشاء"),
        ),
      ],
    );
  }
}

class PrescriptionItemDialog extends StatefulWidget {
  const PrescriptionItemDialog({super.key});

  @override
  State<PrescriptionItemDialog> createState() => PrescriptionItemDialogState();
}

class PrescriptionItemDialogState extends State<PrescriptionItemDialog> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController dosageValueController = TextEditingController();
  String dosageUnit = "mg";
  final List<String> dosageUnits = const [
    "mg",
    "g",
    "ml",
    "IU",
    "tablet",
    "capsule",
    "suppository",
    "drop",
    "puff",
    "ointment",
    "other",
  ];
  final TextEditingController otherUnitController = TextEditingController();

  final TextEditingController frequencyController = TextEditingController();
  String frequencyPreset = "مرة يومياً";
  bool isOtherFrequency = false;
  final List<String> frequencyOptions = const [
    "مرة يومياً",
    "مرتين يومياً",
    "ثلاث مرات يومياً",
    "كل 8 ساعات",
    "كل 12 ساعة",
    "عند اللزوم",
    "أخرى",
  ];

  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();

  bool isPermanent = false;
  static const String permanentEndDate = "2100-01-01";

  final TextEditingController instructionsController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    dosageValueController.dispose();
    otherUnitController.dispose();
    frequencyController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;
    if (picked == null) return;

    final y = picked.year.toString().padLeft(4, "0");
    final m = picked.month.toString().padLeft(2, "0");
    final d = picked.day.toString().padLeft(2, "0");

    controller.text = "$y-$m-$d";
  }

  String? _validateAllFields() {
    final name = nameController.text.trim();
    if (name.isEmpty) return "اسم الدواء مطلوب.";

    final doseVal = dosageValueController.text.trim();
    if (doseVal.isEmpty) return "الجرعة مطلوبة.";

    if (dosageUnit == "other") {
      final other = otherUnitController.text.trim();
      if (other.isEmpty) return "يرجى كتابة وحدة الجرعة.";
    }

    final freq =
        isOtherFrequency ? frequencyController.text.trim() : frequencyPreset;
    if (freq.trim().isEmpty) return "عدد المرات (التردد) مطلوب.";

    final start = startDateController.text.trim();
    if (start.isEmpty) return "تاريخ بدء الدواء مطلوب.";

    final end = endDateController.text.trim();
    if (end.isEmpty) return "تاريخ انتهاء الدواء مطلوب.";

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("إضافة دواء"),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "اسم الدواء *",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: dosageValueController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: "الجرعة *",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: dosageUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "الوحدة *",
                        border: OutlineInputBorder(),
                      ),
                      items:
                          dosageUnits
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          dosageUnit = v;
                          if (dosageUnit != "other") {
                            otherUnitController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),

              if (dosageUnit == "other") ...[
                const SizedBox(height: 10),
                TextField(
                  controller: otherUnitController,
                  decoration: const InputDecoration(
                    labelText: "وحدة أخرى *",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: frequencyPreset,
                items:
                    frequencyOptions
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    frequencyPreset = v;
                    isOtherFrequency = v == "أخرى";
                    if (!isOtherFrequency) {
                      frequencyController.text = v;
                    } else {
                      frequencyController.clear();
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: "عدد المرات *",
                  border: OutlineInputBorder(),
                ),
              ),

              if (isOtherFrequency) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: frequencyController,
                  decoration: const InputDecoration(
                    labelText: "وصف التردد *",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              TextField(
                controller: startDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "تاريخ بدء الدواء *",
                  border: OutlineInputBorder(),
                ),
                onTap: () async => _pickDate(startDateController),
              ),
              const SizedBox(height: 10),

              CheckboxListTile(
                value: isPermanent,
                onChanged: (v) {
                  setState(() {
                    isPermanent = v ?? false;
                    if (isPermanent) {
                      endDateController.text = permanentEndDate;
                    } else {
                      if (endDateController.text.trim() == permanentEndDate) {
                        endDateController.clear();
                      }
                    }
                  });
                },
                title: const Text("دواء دائم"),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 6),
              TextField(
                controller: endDateController,
                readOnly: true,
                enabled: !isPermanent,
                decoration: const InputDecoration(
                  labelText: "تاريخ انتهاء الدواء *",
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  if (isPermanent) return;
                  await _pickDate(endDateController);
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: instructionsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "تعليمات (اختياري)",
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
            final err = _validateAllFields();
            if (err != null) {
              showAppSnackBar(context, err, type: AppSnackBarType.warning);
              return;
            }

            final name = nameController.text.trim();

            final doseVal = dosageValueController.text.trim();
            String unitToUse = dosageUnit;
            if (dosageUnit == "other") {
              unitToUse = otherUnitController.text.trim();
            }
            final dosage = "$doseVal $unitToUse";

            final frequency =
                isOtherFrequency
                    ? frequencyController.text.trim()
                    : frequencyPreset;
            final startRaw = startDateController.text.trim();
            final endRaw = endDateController.text.trim();

            try {
              final start = DateTime.parse(startRaw);
              final end = DateTime.parse(endRaw);
              if (!end.isAfter(start)) {
                showAppSnackBar(
                  context,
                  "تاريخ النهاية يجب أن يكون بعد تاريخ البداية.",
                  type: AppSnackBarType.warning,
                );
                return;
              }
            } catch (_) {
              showAppSnackBar(
                context,
                "صيغة التاريخ غير صحيحة.",
                type: AppSnackBarType.warning,
              );
              return;
            }

            Navigator.pop<Map<String, dynamic>>(context, <String, dynamic>{
              "medicine_name": name,
              "dosage": dosage,
              "frequency": frequency,
              "start_date": startDateController.text.trim(),
              "end_date": endDateController.text.trim(),
              "instructions": instructionsController.text.trim(),
            });
          },
          child: const Text("إضافة"),
        ),
      ],
    );
  }
}
