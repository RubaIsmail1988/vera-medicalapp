import 'dart:convert';
import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

enum _DoctorViewMode { time, medicine }

class AdherenceTab extends StatefulWidget {
  final String role; // doctor | patient
  final int userId;
  final int? selectedPatientId;

  const AdherenceTab({
    super.key,
    required this.role,
    required this.userId,
    required this.selectedPatientId,
  });

  @override
  State<AdherenceTab> createState() => _AdherenceTabState();
}

class _AdherenceTabState extends State<AdherenceTab> {
  late final ClinicalService clinicalService;

  Future<List<Map<String, dynamic>>>? adherenceFuture;
  Future<List<Map<String, dynamic>>>? prescriptionsFuture;

  int? selectedPrescriptionItemId;
  String selectedStatus = "taken";
  final TextEditingController noteController = TextEditingController();

  _DoctorViewMode doctorViewMode = _DoctorViewMode.time;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    adherenceFuture = _fetchAdherence();

    if (isPatient) {
      prescriptionsFuture = _fetchPrescriptions();
    }
  }

  @override
  void didUpdateWidget(covariant AdherenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // عند تبديل المريض المختار للطبيب: نعيد تحميل السجلات لضمان تحديث UI
    if (oldWidget.selectedPatientId != widget.selectedPatientId) {
      setState(() {
        adherenceFuture = _fetchAdherence();
      });
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data fetchers
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchAdherence() async {
    final res = await clinicalService.listAdherence();
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchPrescriptions() async {
    final res = await clinicalService.listPrescriptions();
    if (res.statusCode != 200) return [];
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.cast<Map<String, dynamic>>();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  DateTime _parseDateOrMin(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final dt = DateTime.tryParse(s);
    return (dt ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  String _formatShortDateTime(String raw) {
    final dt = _parseDateOrMin(raw);
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(dt.day)}-${two(dt.month)}-${dt.year} • ${two(dt.hour)}:${two(dt.minute)}";
  }

  String _statusLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "taken") return "تم تناول الجرعة";
    if (v == "missed") return "تم تفويت الجرعة";
    return "غير معروف";
  }

  bool _isTaken(String raw) => raw.trim().toLowerCase() == "taken";
  bool _isMissed(String raw) => raw.trim().toLowerCase() == "missed";

  String _safeText(dynamic v) => (v?.toString() ?? "").trim();

  String _doseFreqLine(String dosage, String frequency) {
    final parts = <String>[];
    if (dosage.trim().isNotEmpty) parts.add(dosage.trim());
    if (frequency.trim().isNotEmpty) parts.add(frequency.trim());
    return parts.join(" · ");
  }

  Map<String, dynamic>? _selectedItemFromPrescriptions(
    List<Map<String, dynamic>> prescriptions,
  ) {
    final itemId = selectedPrescriptionItemId;
    if (itemId == null) return null;

    for (final p in prescriptions) {
      final items = (p["items"] is List) ? (p["items"] as List) : const [];
      for (final it in items) {
        if (it is! Map) continue;
        final id = _asInt(it["id"]);
        if (id == itemId) {
          return it.cast<String, dynamic>();
        }
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Submit adherence (patient)
  // ---------------------------------------------------------------------------

  bool get _canSubmit {
    return isPatient &&
        selectedPrescriptionItemId != null &&
        selectedStatus.trim().isNotEmpty;
  }

  Future<void> submitAdherence() async {
    if (!_canSubmit) return;

    final res = await clinicalService.createAdherence(
      prescriptionItemId: selectedPrescriptionItemId!,
      status: selectedStatus,
      takenAt: DateTime.now(),
      note: noteController.text.trim(),
    );

    if (!mounted) return;

    if (res.statusCode == 201 || res.statusCode == 200) {
      showAppSnackBar(context, "تم تسجيل الالتزام بنجاح.");

      // بعد نجاح التسجيل:
      // - تفريغ الملاحظة
      // - إعادة الحالة للوضع الافتراضي
      // - تحديث السجل مباشرة
      setState(() {
        noteController.clear();
        selectedStatus = "taken";
        adherenceFuture = _fetchAdherence();
      });
      return;
    }

    showAppSnackBar(context, "فشل تسجيل الالتزام.");
  }

  // ---------------------------------------------------------------------------
  // Build: Doctor view mode switch
  // ---------------------------------------------------------------------------

  Widget _buildDoctorModeSwitch() {
    if (!isDoctor) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SegmentedButton<_DoctorViewMode>(
        segments: const <ButtonSegment<_DoctorViewMode>>[
          ButtonSegment<_DoctorViewMode>(
            value: _DoctorViewMode.time,
            label: Text("حسب الوقت"),
            icon: Icon(Icons.schedule),
          ),
          ButtonSegment<_DoctorViewMode>(
            value: _DoctorViewMode.medicine,
            label: Text("حسب الدواء"),
            icon: Icon(Icons.medication_outlined),
          ),
        ],
        selected: <_DoctorViewMode>{doctorViewMode},
        onSelectionChanged: (s) {
          final v = s.isNotEmpty ? s.first : _DoctorViewMode.time;
          setState(() => doctorViewMode = v);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build: Adherence list (time view)
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _filterAndSortForView(
    List<Map<String, dynamic>> all,
  ) {
    // طبيب: فلترة حسب المريض المختار إن وجد
    final view =
        (isDoctor && widget.selectedPatientId != null)
            ? all
                .where(
                  (a) =>
                      _safeText(a["patient"]) ==
                      widget.selectedPatientId.toString(),
                )
                .toList()
            : all;

    // ترتيب الأحدث أولًا
    view.sort((a, b) {
      final at = _parseDateOrMin(_safeText(a["taken_at"]));
      final bt = _parseDateOrMin(_safeText(b["taken_at"]));
      return bt.compareTo(at);
    });

    return view;
  }

  Widget _buildStatusChip(String rawStatus) {
    final scheme = Theme.of(context).colorScheme;

    final bg =
        _isTaken(rawStatus)
            ? scheme.primaryContainer
            : _isMissed(rawStatus)
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest;

    final fg =
        _isTaken(rawStatus)
            ? scheme.onPrimaryContainer
            : _isMissed(rawStatus)
            ? scheme.onErrorContainer
            : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(rawStatus),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAdherenceCard(Map<String, dynamic> a) {
    final medicineName = _safeText(a["medicine_name"]);
    final dosage = _safeText(a["dosage"]);
    final frequency = _safeText(a["frequency"]);
    final note = _safeText(a["note"]);
    final takenAtRaw = _safeText(a["taken_at"]);
    final statusRaw = _safeText(a["status"]);

    final doseFreq = _doseFreqLine(dosage, frequency);
    final dtLine =
        takenAtRaw.isNotEmpty ? _formatShortDateTime(takenAtRaw) : "";

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // line 1: medicine + chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    medicineName.isNotEmpty ? medicineName : "دواء",
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                _buildStatusChip(statusRaw),
              ],
            ),
            if (doseFreq.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                doseFreq,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (dtLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(dtLine, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "ملاحظة: $note",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeList(List<Map<String, dynamic>> view) {
    if (view.isEmpty) {
      return const Center(child: Text("لا توجد سجلات التزام."));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: view.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildAdherenceCard(view[i]),
    );
  }

  // ---------------------------------------------------------------------------
  // Build: Grouped by medicine (doctor only)
  // ---------------------------------------------------------------------------

  Map<int, List<Map<String, dynamic>>> _groupByPrescriptionItem(
    List<Map<String, dynamic>> view,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};

    for (final a in view) {
      // نعتمد prescription_item كـ id للتجميع (FK)
      final itemId = _asInt(a["prescription_item"]);
      if (itemId == null) continue;
      map.putIfAbsent(itemId, () => <Map<String, dynamic>>[]).add(a);
    }

    // داخل كل مجموعة: ترتيب الأحدث أولًا
    for (final entry in map.entries) {
      entry.value.sort((a, b) {
        final at = _parseDateOrMin(_safeText(a["taken_at"]));
        final bt = _parseDateOrMin(_safeText(b["taken_at"]));
        return bt.compareTo(at);
      });
    }

    return map;
  }

  String _groupTitleFromFirst(Map<String, dynamic> a) {
    final name = _safeText(a["medicine_name"]);
    final dosage = _safeText(a["dosage"]);
    final freq = _safeText(a["frequency"]);
    final doseFreq = _doseFreqLine(dosage, freq);

    final title = name.isNotEmpty ? name : "دواء";
    return doseFreq.isNotEmpty ? "$title • $doseFreq" : title;
  }

  Widget _buildGroupedList(List<Map<String, dynamic>> view) {
    if (view.isEmpty) {
      return const Center(child: Text("لا توجد سجلات التزام."));
    }

    final grouped = _groupByPrescriptionItem(view);

    // قد توجد سجلات بدون prescription_item (نادر)؛ نعرضها آخر شيء كقائمة زمنية
    final leftovers =
        view.where((a) => _asInt(a["prescription_item"]) == null).toList();

    final keys = grouped.keys.toList()..sort(); // ترتيب ثابت للمجموعات

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final k in keys) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _groupTitleFromFirst(grouped[k]!.first),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...grouped[k]!.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAdherenceCard(a),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (leftovers.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "سجلات أخرى",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ...leftovers.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildAdherenceCard(a),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Patient: Build medicine dropdown (two lines) + selected details card
  // ---------------------------------------------------------------------------

  Widget _medicineDropdownTwoLines(List<Map<String, dynamic>> prescriptions) {
    final items = <Map<String, dynamic>>[];
    for (final p in prescriptions) {
      if (p["items"] is List) {
        items.addAll((p["items"] as List).cast<Map<String, dynamic>>());
      }
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "لا توجد وصفات طبية مسجّلة، لا يمكن تسجيل الالتزام الدوائي.",
          textAlign: TextAlign.center,
        ),
      );
    }

    final options = <DropdownMenuItem<int>>[];
    for (final it in items) {
      final id = _asInt(it["id"]);
      if (id == null) continue;

      final name =
          _safeText(it["medicine_name"]).isNotEmpty
              ? _safeText(it["medicine_name"])
              : "دواء";

      final dosage = _safeText(it["dosage"]);
      final freq = _safeText(it["frequency"]);
      final secondLine = _doseFreqLine(dosage, freq);

      options.add(
        DropdownMenuItem<int>(
          value: id,
          child: SizedBox(
            height: 56, // يمنع overflow داخل عناصر القائمة
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (secondLine.isNotEmpty)
                  Text(
                    secondLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedIt = _selectedItemFromPrescriptions(prescriptions);

    Widget selectedDetailsCard() {
      if (selectedIt == null) return const SizedBox.shrink();

      final name =
          _safeText(selectedIt["medicine_name"]).isNotEmpty
              ? _safeText(selectedIt["medicine_name"])
              : "دواء";
      final dosage = _safeText(selectedIt["dosage"]);
      final freq = _safeText(selectedIt["frequency"]);
      final instructions = _safeText(selectedIt["instructions"]);
      final startDate = _safeText(selectedIt["start_date"]);
      final endDate = _safeText(selectedIt["end_date"]);

      Widget line(String label, String value) {
        if (value.trim().isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text("$label: $value"),
        );
      }

      return Card(
        margin: const EdgeInsets.only(top: 10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (_doseFreqLine(dosage, freq).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_doseFreqLine(dosage, freq)),
              ],
              line("التعليمات", instructions),
              line("تاريخ البدء", startDate),
              line("تاريخ الانتهاء", endDate),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        DropdownButtonFormField<int>(
          isExpanded: true,
          itemHeight: 64, // مهم لمنع RenderFlex overflow في عناصر القائمة
          decoration: const InputDecoration(
            labelText: "اختر الدواء",
            border: OutlineInputBorder(),
          ),
          items: options,
          value:
              (selectedPrescriptionItemId != null &&
                      options.any((m) => m.value == selectedPrescriptionItemId))
                  ? selectedPrescriptionItemId
                  : null,
          // عند عرض العنصر المحدد في الحقل، نعرض سطر واحد فقط لتجنب أي قيود ارتفاع
          selectedItemBuilder: (ctx) {
            return options.map((opt) {
              final it = items.firstWhere(
                (x) => _asInt(x["id"]) == opt.value,
                orElse: () => <String, dynamic>{},
              );
              final name =
                  _safeText(it["medicine_name"]).isNotEmpty
                      ? _safeText(it["medicine_name"])
                      : "دواء";
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            }).toList();
          },
          onChanged: (v) => setState(() => selectedPrescriptionItemId = v),
        ),
        selectedDetailsCard(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Main build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // -------------------------------
    // PATIENT VIEW
    // -------------------------------
    if (isPatient) {
      return Column(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: prescriptionsFuture,
            builder: (context, snapshot) {
              final prescriptions = snapshot.data ?? [];

              return Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "تسجيل الالتزام الدوائي",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),

                        _medicineDropdownTwoLines(prescriptions),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: "الحالة",
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: "taken",
                              child: Text("تم تناول الجرعة"),
                            ),
                            DropdownMenuItem(
                              value: "missed",
                              child: Text("تم تفويت الجرعة"),
                            ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => selectedStatus = v);
                          },
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: "ملاحظة (اختياري)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? submitAdherence : null,
                            child: const Text("تسجيل"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: adherenceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? [];
                final view = _filterAndSortForView(all);
                return _buildTimeList(view);
              },
            ),
          ),
        ],
      );
    }

    // -------------------------------
    // DOCTOR VIEW (READ ONLY + toggle)
    // -------------------------------
    return Column(
      children: [
        _buildDoctorModeSwitch(),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: adherenceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final all = snapshot.data ?? [];
              final view = _filterAndSortForView(all);

              if (doctorViewMode == _DoctorViewMode.medicine) {
                return _buildGroupedList(view);
              }

              return _buildTimeList(view);
            },
          ),
        ),
      ],
    );
  }
}
