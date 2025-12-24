import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

class PrescriptionsTab extends StatefulWidget {
  final String role;
  final int userId;
  final int? selectedPatientId; // Phase D-2

  const PrescriptionsTab({
    super.key,
    required this.role,
    required this.userId,
    this.selectedPatientId,
  });

  @override
  State<PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<PrescriptionsTab> {
  late final ClinicalService clinicalService;

  Future<List<Map<String, dynamic>>>? prescriptionsFuture;

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    prescriptionsFuture = fetchPrescriptions();
  }

  @override
  void didUpdateWidget(covariant PrescriptionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPatientId != widget.selectedPatientId) {
      reload();
    }
  }

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  int? asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<List<Map<String, dynamic>>> fetchPrescriptions() async {
    final response = await clinicalService.listPrescriptions();

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<Map<String, dynamic>> list =
          decoded is List
              ? decoded.cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      final selectedPid = widget.selectedPatientId;
      List<Map<String, dynamic>> filtered = list;

      if (isDoctor && selectedPid != null) {
        filtered =
            list.where((p) {
              final pid = asInt(p["patient"]);
              return pid == selectedPid;
            }).toList();
      }

      filtered.sort((a, b) {
        final aRaw = a["created_at"]?.toString() ?? "";
        final bRaw = b["created_at"]?.toString() ?? "";
        final ad = parseCreatedAtOrMin(aRaw);
        final bd = parseCreatedAtOrMin(bRaw);
        return bd.compareTo(ad);
      });

      return filtered;
    }

    if (response.statusCode == 401) {
      throw HttpException(401, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
    }

    if (response.statusCode == 403) {
      throw HttpException(403, "لا تملك الصلاحية لعرض الوصفات.");
    }

    try {
      final body = jsonDecode(response.body);
      final detail =
          body is Map && body["detail"] != null
              ? body["detail"].toString()
              : null;
      throw HttpException(response.statusCode, detail ?? "حدث خطأ غير متوقع.");
    } catch (_) {
      throw HttpException(response.statusCode, "حدث خطأ غير متوقع.");
    }
  }

  Future<void> reload() async {
    setState(() {
      prescriptionsFuture = fetchPrescriptions();
    });
  }

  String formatDateTime(String raw) {
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

  DateTime parseCreatedAtOrMin(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  // ---------------------------------------------------------------------------
  // Prescription Details (Dialog) - UI only (كما عندك)
  // ---------------------------------------------------------------------------
  Future<void> openPrescriptionDetails(
    int prescriptionId, {
    required String doctorDisplayName,
    String? createdAtRawFromList,
  }) async {
    final response = await clinicalService.getPrescriptionDetails(
      prescriptionId,
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final items =
          (data is Map && data["items"] is List)
              ? (data["items"] as List).cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[];

      final createdAtRaw =
          (createdAtRawFromList?.trim().isNotEmpty ?? false)
              ? createdAtRawFromList!.trim()
              : ((data is Map && data["created_at"] != null)
                  ? data["created_at"].toString()
                  : "");

      final createdAtFormatted =
          createdAtRaw.isNotEmpty ? formatDateTime(createdAtRaw) : "";

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
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
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

        final startDateFormatted =
            startDateRaw.isNotEmpty ? formatDateTime(startDateRaw) : "";
        final endDateFormatted =
            endDateRaw.isNotEmpty ? formatDateTime(endDateRaw) : "";

        final lines = <Widget>[];

        if (name.isNotEmpty) {
          lines.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                name,
                style: Theme.of(context).textTheme.titleSmall,
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

        if (startDateFormatted.isNotEmpty) {
          lines.add(
            labeledLine(label: "تاريخ بدء الدواء", value: startDateFormatted),
          );
        }

        if (endDateFormatted.isNotEmpty) {
          lines.add(
            labeledLine(label: "تاريخ انتهاء الدواء", value: endDateFormatted),
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

      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Center(
              child: Text("تفاصيل وصفتك", textAlign: TextAlign.center),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
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
                            ? const Center(child: Text("لا توجد تفاصيل متاحة."))
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
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
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

      return;
    }

    if (response.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }

    if (response.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لعرض تفاصيل الوصفة.");
      return;
    }

    showAppSnackBar(context, "فشل تحميل التفاصيل (${response.statusCode}).");
  }

  // ---------------------------------------------------------------------------
  Future<void> createPrescriptionFlow() async {
    if (!isDoctor) {
      showAppSnackBar(context, "هذه العملية متاحة للطبيب فقط.");
      return;
    }

    final patientId = widget.selectedPatientId;
    if (patientId == null || patientId <= 0) {
      showAppSnackBar(context, "يرجى اختيار مريض أولًا قبل إنشاء وصفة.");
      return;
    }

    final payload = await showDialog<CreatePrescriptionPayload>(
      context: context,
      builder: (_) => const CreatePrescriptionDialog(),
    );

    if (!mounted) return;
    if (payload == null) return;

    final response = await clinicalService.createPrescription(
      doctorId: widget.userId,
      patientId: patientId,
      notes: payload.notes,
      items: payload.items,
    );

    if (!mounted) return;

    if (response.statusCode == 201) {
      showAppSnackBar(context, "تم إنشاء الوصفة بنجاح.");
      await reload();
      return;
    }

    if (response.statusCode == 401) {
      showAppSnackBar(context, "انتهت الجلسة، يرجى تسجيل الدخول مجددًا.");
      return;
    }

    if (response.statusCode == 403) {
      showAppSnackBar(context, "لا تملك الصلاحية لإنشاء وصفة.");
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
        detail ?? "فشل إنشاء الوصفة (${response.statusCode}).",
      );
    } catch (_) {
      showAppSnackBar(context, "فشل إنشاء الوصفة (${response.statusCode}).");
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
                onPressed: () async => createPrescriptionFlow(),
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
                final err = snapshot.error;
                String message = "حدث خطأ.";
                if (err is HttpException) message = err.message;

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

              final viewList = snapshot.data ?? [];

              if (viewList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 40),
                        SizedBox(height: 12),
                        Text(
                          "لا توجد وصفات طبية مسجّلة حتى الآن",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: viewList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = viewList[index];

                    final idStr = p["id"]?.toString() ?? "";
                    final prescriptionId = int.tryParse(idStr);

                    final createdAtRaw = p["created_at"]?.toString() ?? "";
                    final createdAt = formatDateTime(createdAtRaw);

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
                          "وصفة طبية صادرة من الطبيب: د. $doctorDisplayName",
                          maxLines: 1,
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
                                this.context,
                                "تعذر فتح التفاصيل.",
                              );
                              return;
                            }
                            await openPrescriptionDetails(
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

class HttpException implements Exception {
  final int statusCode;
  final String message;

  HttpException(this.statusCode, this.message);

  @override
  String toString() => "HTTP $statusCode: $message";
}

class CreatePrescriptionPayload {
  final String notes;
  final List<Map<String, dynamic>> items;

  CreatePrescriptionPayload({required this.notes, required this.items});
}

// Dialog إنشاء الوصفة للطبيب: بدون patientId
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

  Future<void> addItemDialog() async {
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
                  labelText: "Notes (اختياري)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text("Items: ${items.length}")),
                  TextButton.icon(
                    onPressed: () async => addItemDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text("Add item"),
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
                      final endDate = it["end_date"]?.toString() ?? "";
                      final endLabel =
                          endDate.trim().isNotEmpty ? endDate : "بدون نهاية";

                      return ListTile(
                        title: Text(name.isNotEmpty ? name : "دواء"),
                        subtitle: Text(
                          "${dosage.isNotEmpty ? dosage : ""}"
                          "${(dosage.isNotEmpty && freq.isNotEmpty) ? " · " : ""}"
                          "${freq.isNotEmpty ? freq : ""}"
                          "${endLabel.isNotEmpty ? "\nتاريخ الانتهاء: $endLabel" : ""}",
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
              showAppSnackBar(context, "أضف دواء واحد على الأقل.");
              return;
            }

            for (final it in items) {
              final endDate = it["end_date"]?.toString().trim() ?? "";
              if (endDate.isEmpty) {
                showAppSnackBar(context, "يرجى إدخال تاريخ انتهاء الدواء");
                return;
              }
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

// PrescriptionItemDialog: كما هو عندك (بدون تعديل)
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
  String frequencyPreset = "مرة يوميًا";
  bool isOtherFrequency = false;
  final List<String> frequencyOptions = const [
    "مرة يوميًا",
    "مرتين يوميًا",
    "ثلاث مرات يوميًا",
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

  Future<void> pickDate(TextEditingController controller) async {
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
                  labelText: "اسم الدواء",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dosageValueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "الجرعة",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String>(
                      value: dosageUnit,
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
                      decoration: const InputDecoration(
                        labelText: "الوحدة",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (dosageUnit == "other") ...[
                const SizedBox(height: 10),
                TextField(
                  controller: otherUnitController,
                  decoration: const InputDecoration(
                    labelText: "وحدة أخرى",
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
                  labelText: "عدد المرات",
                  border: OutlineInputBorder(),
                ),
              ),
              if (isOtherFrequency) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: frequencyController,
                  decoration: const InputDecoration(
                    labelText: "وصف التردد",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: startDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "تاريخ بدء الدواء",
                  border: OutlineInputBorder(),
                ),
                onTap: () async => pickDate(startDateController),
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
                  labelText: "تاريخ انتهاء الدواء",
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  if (isPermanent) return;
                  await pickDate(endDateController);
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
            final name = nameController.text.trim();
            if (name.isEmpty) {
              showAppSnackBar(context, "اسم الدواء مطلوب.");
              return;
            }

            final endDate = endDateController.text.trim();
            if (endDate.isEmpty) {
              showAppSnackBar(context, "يرجى إدخال تاريخ انتهاء الدواء");
              return;
            }

            final doseVal = dosageValueController.text.trim();
            String unitToUse = dosageUnit;
            if (dosageUnit == "other") {
              final other = otherUnitController.text.trim();
              if (other.isNotEmpty) unitToUse = other;
            }

            final dosage = doseVal.isNotEmpty ? "$doseVal $unitToUse" : "";

            final frequency =
                isOtherFrequency
                    ? frequencyController.text.trim()
                    : frequencyPreset;

            Navigator.pop<Map<String, dynamic>>(context, <String, dynamic>{
              "medicine_name": name,
              "dosage": dosage,
              "frequency": frequency,
              "start_date": startDateController.text.trim(),
              "end_date": endDate,
              "instructions": instructionsController.text.trim(),
            });
          },
          child: const Text("إضافة"),
        ),
      ],
    );
  }
}
