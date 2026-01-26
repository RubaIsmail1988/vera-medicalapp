import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

enum _DoctorViewMode { time, medicine }

enum _RangeGate { ok, notStarted, ended, invalidOrMissing }

class AdherenceTab extends StatefulWidget {
  final String role; // doctor | patient
  final int userId;
  final int? selectedPatientId;

  final int? selectedAppointmentId;

  const AdherenceTab({
    super.key,
    required this.role,
    required this.userId,
    required this.selectedPatientId,
    this.selectedAppointmentId,
  });

  @override
  State<AdherenceTab> createState() => _AdherenceTabState();
}

class _AdherenceTabState extends State<AdherenceTab> {
  late final ClinicalService clinicalService;

  Future<List<Map<String, dynamic>>>? adherenceFuture;
  Future<List<Map<String, dynamic>>>? prescriptionsFuture;

  Object? lastAdherenceError;
  Object? lastPrescriptionsError;

  int? selectedPrescriptionItemId;
  String selectedStatus = "taken"; // taken | skipped
  final TextEditingController noteController = TextEditingController();

  _DoctorViewMode doctorViewMode = _DoctorViewMode.time;

  // Patient selection context (used for bottom sheet only)
  Map<String, dynamic>? selectedItem;
  Map<String, dynamic>? selectedPrescription;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  bool get _hasAppointmentFilter {
    final apptId = widget.selectedAppointmentId;
    return apptId != null && apptId > 0;
  }

  @override
  void initState() {
    super.initState();
    clinicalService = ClinicalService(authService: AuthService());
    _reloadAll();
  }

  @override
  void didUpdateWidget(covariant AdherenceTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final patientChanged =
        oldWidget.selectedPatientId != widget.selectedPatientId;
    final apptChanged =
        oldWidget.selectedAppointmentId != widget.selectedAppointmentId;

    if (patientChanged || apptChanged) {
      setState(() {
        // Reset selection only when appointment changes (as before)
        if (apptChanged) {
          selectedPrescriptionItemId = null;
          selectedItem = null;
          selectedPrescription = null;
          noteController.clear();
          selectedStatus = "taken";
        }
      });

      _reloadAll();
    }
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fetch (Inline errors only)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchAdherence() async {
    final res = await clinicalService.listAdherence();

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.cast<Map<String, dynamic>>();
    }

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = res.body;
    }

    final message = mapHttpErrorToArabicMessage(
      statusCode: res.statusCode,
      data: decoded,
    );
    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> _fetchPrescriptions() async {
    final res = await clinicalService.listPrescriptions();

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.cast<Map<String, dynamic>>();
    }

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = res.body;
    }

    final message = mapHttpErrorToArabicMessage(
      statusCode: res.statusCode,
      data: decoded,
    );
    throw Exception(message);
  }

  void _reloadAll() {
    lastAdherenceError = null;
    lastPrescriptionsError = null;

    final newAdherenceFuture = _fetchAdherence().catchError((e) {
      lastAdherenceError = e;
      throw e;
    });

    Future<List<Map<String, dynamic>>>? newPrescriptionsFuture;
    if (isPatient) {
      newPrescriptionsFuture = _fetchPrescriptions().catchError((e) {
        lastPrescriptionsError = e;
        throw e;
      });
    } else {
      newPrescriptionsFuture = null;
    }

    if (!mounted) return;
    setState(() {
      adherenceFuture = newAdherenceFuture;
      prescriptionsFuture = newPrescriptionsFuture;
    });
  }

  bool _looksOffline(Object? e) {
    if (e == null) return false;
    final s = mapFetchExceptionToInlineState(e);
    return s.title.contains('لا يوجد اتصال');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  String _safeText(dynamic v) => (v?.toString() ?? "").trim();

  DateTime _parseDateOrMin(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final dt = DateTime.tryParse(s);
    return (dt ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal();
  }

  DateTime? _tryParseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatShortDateTime(String raw) {
    final dt = _parseDateOrMin(raw);
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(dt.day)}-${two(dt.month)}-${dt.year} • ${two(dt.hour)}:${two(dt.minute)}";
  }

  String _formatShortDate(String raw) {
    final dt = _tryParseDate(raw);
    if (dt == null) return raw.trim();
    String two(int v) => v.toString().padLeft(2, "0");
    return "${two(dt.day)}-${two(dt.month)}-${dt.year}";
  }

  String _doseFreqLine(String dosage, String frequency) {
    final parts = <String>[];
    if (dosage.trim().isNotEmpty) parts.add(dosage.trim());
    if (frequency.trim().isNotEmpty) parts.add(frequency.trim());
    return parts.join(" · ");
  }

  String _statusLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "taken") return "تم تناول الجرعة";
    if (v == "skipped") return "تم تفويت الجرعة";
    if (v == "missed") return "تم تفويت الجرعة";
    return "غير معروف";
  }

  bool _isTaken(String raw) => raw.trim().toLowerCase() == "taken";

  bool _isMissedLike(String raw) {
    final v = raw.trim().toLowerCase();
    return v == "skipped" || v == "missed";
  }

  String _statusForSend(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "taken") return "taken";
    if (v == "skipped") return "skipped";
    return "skipped";
  }

  String _prescriptionCreatedAtFromAdherence(Map<String, dynamic> a) {
    return _safeText(a["prescription_created_at"]).isNotEmpty
        ? _safeText(a["prescription_created_at"])
        : _safeText(a["prescription_date"]).isNotEmpty
        ? _safeText(a["prescription_date"])
        : _safeText(a["prescription_created"]).isNotEmpty
        ? _safeText(a["prescription_created"])
        : "";
  }

  _RangeGate _rangeGateFromSelectedItem() {
    final it = selectedItem;
    if (it == null) return _RangeGate.invalidOrMissing;

    final startRaw = _safeText(it["start_date"]);
    final endRaw = _safeText(it["end_date"]);

    final start = _tryParseDate(startRaw);
    final end = _tryParseDate(endRaw);

    if (start == null || end == null) return _RangeGate.invalidOrMissing;

    final today = _today();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    if (today.isBefore(startDay)) return _RangeGate.notStarted;
    if (today.isAfter(endDay)) return _RangeGate.ended;
    return _RangeGate.ok;
  }

  String _rangeGateMessage(_RangeGate gate) {
    if (gate == _RangeGate.notStarted) return "لم يبدأ الدواء بعد";
    if (gate == _RangeGate.ended) return "انتهت فترة هذا الدواء";
    if (gate == _RangeGate.invalidOrMissing) return "فترة الدواء غير متاحة";
    return "";
  }

  // ---------------------------------------------------------------------------
  // Patient bottom sheets
  // ---------------------------------------------------------------------------

  void _showDetailsBottomSheet() {
    if (!isPatient) return;
    final p = selectedPrescription;
    final it = selectedItem;
    if (p == null || it == null) return;

    final doctorName =
        _safeText(p["doctor_display_name"]).isNotEmpty
            ? _safeText(p["doctor_display_name"])
            : "طبيب غير معروف";

    final createdAtRaw = _safeText(p["created_at"]);
    final createdAtShort =
        createdAtRaw.isNotEmpty ? _formatShortDate(createdAtRaw) : "";

    final dosage = _safeText(it["dosage"]);
    final freq = _safeText(it["frequency"]);
    final instructions = _safeText(it["instructions"]);
    final startDate = _safeText(it["start_date"]);
    final endDate = _safeText(it["end_date"]);

    final warnings = <String>[];
    final today = _today();

    final start = _tryParseDate(startDate);
    final end = _tryParseDate(endDate);

    if (end != null) {
      final endDay = DateTime(end.year, end.month, end.day);
      if (endDay.isBefore(today)) warnings.add("انتهت فترة هذا الدواء");
    }

    if (start != null) {
      final startDay = DateTime(start.year, start.month, start.day);
      if (startDay.isAfter(today)) warnings.add("لم يبدأ الدواء بعد");
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;

        Widget line(String label, String value) {
          if (value.trim().isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              "$label: $value",
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doctorName,
                          style: Theme.of(ctx).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (createdAtShort.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          createdAtShort,
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (_doseFreqLine(dosage, freq).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _doseFreqLine(dosage, freq),
                      style: Theme.of(ctx).textTheme.bodyLarge,
                    ),
                  ],

                  line("التعليمات", instructions),
                  line("تاريخ البدء", startDate),
                  line("تاريخ الانتهاء", endDate),

                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...warnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          w,
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("إغلاق"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNoteBottomSheet() {
    final localController = TextEditingController(text: noteController.text);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ملاحظة", style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: localController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "اكتب الملاحظة هنا...",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              noteController.text = localController.text.trim();
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text("حفظ"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text("إغلاق"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(localController.dispose);
  }

  // ---------------------------------------------------------------------------
  // Submit adherence (patient) -> Action (SnackBar allowed)
  // ---------------------------------------------------------------------------

  bool get _canSubmitCore {
    return isPatient &&
        selectedPrescriptionItemId != null &&
        selectedStatus.trim().isNotEmpty;
  }

  bool get _canSubmitWithRange {
    if (!_canSubmitCore) return false;
    return _rangeGateFromSelectedItem() == _RangeGate.ok;
  }

  Future<void> submitAdherence() async {
    if (!_canSubmitWithRange) return;

    final itemId = selectedPrescriptionItemId;
    if (itemId == null) return;

    final res = await clinicalService.createAdherence(
      prescriptionItemId: itemId,
      status: _statusForSend(selectedStatus),
      takenAt: DateTime.now(),
      note: noteController.text.trim(),
    );

    if (!mounted) return;

    if (res.statusCode == 201 || res.statusCode == 200) {
      showAppSnackBar(
        context,
        "تم تسجيل الالتزام بنجاح.",
        type: AppSnackBarType.success,
      );

      setState(() {
        noteController.clear();
        selectedStatus = "taken";
      });

      _reloadAll(); // يعيد تحميل السجل + الوصفات (للاتساق)
      return;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      decoded = res.body;
    }

    showActionErrorSnackBar(
      context,
      statusCode: res.statusCode,
      data: decoded,
      fallback: "فشل تسجيل الالتزام.",
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor view mode switch
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
  // Filtering / sorting
  // ---------------------------------------------------------------------------

  List<Map<String, dynamic>> _filterAndSortForView(
    List<Map<String, dynamic>> all,
  ) {
    final pid = widget.selectedPatientId;
    final apptId = widget.selectedAppointmentId;

    List<Map<String, dynamic>> view = all;

    if (isDoctor && pid != null && pid > 0) {
      view = view.where((a) => _asInt(a["patient"]) == pid).toList();
    }

    if (apptId != null && apptId > 0) {
      view =
          view.where((a) {
            final aApptId = _asInt(a["appointment_id"]);
            final legacy = _asInt(a["appointment"]);
            return (aApptId ?? legacy) == apptId;
          }).toList();
    }

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
            : _isMissedLike(rawStatus)
            ? scheme.errorContainer
            : scheme.surfaceContainerHighest;

    final fg =
        _isTaken(rawStatus)
            ? scheme.onPrimaryContainer
            : _isMissedLike(rawStatus)
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
    final scheme = Theme.of(context).colorScheme;

    final medicineName = _safeText(a["medicine_name"]);
    final dosage = _safeText(a["dosage"]);
    final frequency = _safeText(a["frequency"]);
    final note = _safeText(a["note"]);
    final takenAtRaw = _safeText(a["taken_at"]);
    final statusRaw = _safeText(a["status"]);

    final doseFreq = _doseFreqLine(dosage, frequency);
    final dtLine =
        takenAtRaw.isNotEmpty ? _formatShortDateTime(takenAtRaw) : "";

    final titleLeft = medicineName.isNotEmpty ? medicineName : "دواء";

    final rxCreatedAtRaw = _prescriptionCreatedAtFromAdherence(a);
    final rxCreatedAtShort =
        rxCreatedAtRaw.isNotEmpty ? _formatShortDate(rxCreatedAtRaw) : "";

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          titleLeft,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDoctor && rxCreatedAtShort.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(
                          rxCreatedAtShort,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
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
      return Center(
        child: Text(
          _hasAppointmentFilter
              ? "لا توجد سجلات التزام مرتبطة بهذا الموعد."
              : "لا توجد سجلات التزام.",
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: view.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildAdherenceCard(view[i]),
    );
  }

  // ---------------------------------------------------------------------------
  // Grouped by medicine (doctor only)
  // ---------------------------------------------------------------------------

  Map<int, List<Map<String, dynamic>>> _groupByPrescriptionItem(
    List<Map<String, dynamic>> view,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};

    for (final a in view) {
      final itemId = _asInt(a["prescription_item"]);
      if (itemId == null) continue;
      map.putIfAbsent(itemId, () => <Map<String, dynamic>>[]).add(a);
    }

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
      return Center(
        child: Text(
          _hasAppointmentFilter
              ? "لا توجد سجلات التزام مرتبطة بهذا الموعد."
              : "لا توجد سجلات التزام.",
        ),
      );
    }

    final grouped = _groupByPrescriptionItem(view);
    final leftovers =
        view.where((a) => _asInt(a["prescription_item"]) == null).toList();

    final keys = grouped.keys.toList()..sort();

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
  // Patient: Medicine dropdown + etc (كما هو)
  // ---------------------------------------------------------------------------

  Widget _medicineDropdownTwoLines(List<Map<String, dynamic>> prescriptions) {
    final apptId = widget.selectedAppointmentId;
    final List<Map<String, dynamic>> rxList =
        (apptId != null && apptId > 0)
            ? prescriptions
                .where((p) => _asInt(p["appointment"]) == apptId)
                .toList()
            : prescriptions;

    final flattened = <Map<String, dynamic>>[];
    for (final p in rxList) {
      if (p["items"] is! List) continue;
      for (final it in (p["items"] as List)) {
        if (it is! Map) continue;
        flattened.add({"prescription": p, "item": it.cast<String, dynamic>()});
      }
    }

    if (flattened.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _hasAppointmentFilter
              ? "لا توجد أدوية ضمن هذا الموعد، لا يمكن تسجيل الالتزام الدوائي."
              : "لا توجد وصفات طبية مسجّلة، لا يمكن تسجيل الالتزام الدوائي.",
          textAlign: TextAlign.center,
        ),
      );
    }

    final options = <DropdownMenuItem<int>>[];

    for (final f in flattened) {
      final p = f["prescription"] as Map<String, dynamic>;
      final it = f["item"] as Map<String, dynamic>;

      final id = _asInt(it["id"]);
      if (id == null) continue;

      final name =
          _safeText(it["medicine_name"]).isNotEmpty
              ? _safeText(it["medicine_name"])
              : "دواء";

      final secondLine = _doseFreqLine(
        _safeText(it["dosage"]),
        _safeText(it["frequency"]),
      );

      final createdAtRaw = _safeText(p["created_at"]);
      final createdAtShort =
          createdAtRaw.isNotEmpty ? _formatShortDate(createdAtRaw) : "";

      options.add(
        DropdownMenuItem<int>(
          value: id,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 10),
                if (createdAtShort.isNotEmpty)
                  Text(
                    createdAtShort,
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

    return DropdownButtonFormField<int>(
      isExpanded: true,
      itemHeight: 64,
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
      selectedItemBuilder: (ctx) {
        return options.map((opt) {
          final found = flattened.firstWhere(
            (x) =>
                _asInt((x["item"] as Map<String, dynamic>)["id"]) == opt.value,
            orElse: () => <String, dynamic>{},
          );

          final it =
              (found["item"] is Map<String, dynamic>)
                  ? (found["item"] as Map<String, dynamic>)
                  : <String, dynamic>{};

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
      onChanged: (v) {
        setState(() {
          selectedPrescriptionItemId = v;

          if (v == null) {
            selectedItem = null;
            selectedPrescription = null;
            return;
          }

          final found = flattened.firstWhere(
            (x) => _asInt((x["item"] as Map<String, dynamic>)["id"]) == v,
            orElse: () => <String, dynamic>{},
          );

          selectedItem =
              (found["item"] is Map<String, dynamic>)
                  ? (found["item"] as Map<String, dynamic>)
                  : null;

          selectedPrescription =
              (found["prescription"] is Map<String, dynamic>)
                  ? (found["prescription"] as Map<String, dynamic>)
                  : null;
        });
      },
    );
  }

  Widget _statusSegmented({required bool isDisabled}) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment<String>(
          value: "taken",
          label: Text("تناولتها"),
          icon: Icon(Icons.check_circle_outline),
        ),
        ButtonSegment<String>(
          value: "skipped",
          label: Text("نسيتها"),
          icon: Icon(Icons.cancel_outlined),
        ),
      ],
      selected: <String>{selectedStatus},
      onSelectionChanged:
          isDisabled
              ? null
              : (s) {
                final v = s.isNotEmpty ? s.first : "taken";
                setState(() => selectedStatus = v);
              },
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // -------------------------------
    // PATIENT VIEW
    // -------------------------------
    if (isPatient) {
      // إذا انقطع الإنترنت: نعرض حالة واحدة فقط بدل نصفين خطأ
      final offline =
          _looksOffline(lastPrescriptionsError) ||
          _looksOffline(lastAdherenceError);

      if (offline &&
          (lastPrescriptionsError != null || lastAdherenceError != null)) {
        final err = lastPrescriptionsError ?? lastAdherenceError!;
        return AppFetchStateView(error: err, onRetry: _reloadAll);
      }

      final scheme = Theme.of(context).colorScheme;

      final hasSelection = selectedPrescriptionItemId != null;
      final gate =
          hasSelection
              ? _rangeGateFromSelectedItem()
              : _RangeGate.invalidOrMissing;
      final gateMsg =
          (hasSelection && gate != _RangeGate.ok)
              ? _rangeGateMessage(gate)
              : "";
      final isOutsideRange = hasSelection && gate != _RangeGate.ok;

      final canDetails =
          hasSelection && selectedItem != null && selectedPrescription != null;
      final canSubmit = _canSubmitWithRange;
      final submitLabel = canSubmit ? "تسجيل" : "غير متاح";

      return Column(
        children: [
          // Top: form
          Expanded(
            flex: 2,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: prescriptionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppFetchStateView(
                      error: snapshot.error!,
                      onRetry: () {
                        _reloadAll();
                      },
                    ),
                  );
                }

                final prescriptions = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Card(
                    color: scheme.surfaceContainerHighest,
                    elevation: 0,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _medicineDropdownTwoLines(prescriptions),

                          if (gateMsg.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              gateMsg,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _statusSegmented(isDisabled: isOutsideRange),
                              OutlinedButton(
                                onPressed:
                                    canDetails ? _showDetailsBottomSheet : null,
                                child: const Text(" التفاصيل"),
                              ),
                              OutlinedButton(
                                onPressed:
                                    isOutsideRange
                                        ? null
                                        : _showNoteBottomSheet,
                                child: const Text("ملاحظة"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: canSubmit ? submitAdherence : null,
                              child: Text(submitLabel),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom: adherence log
          Expanded(
            flex: 3,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Align(
                    alignment: Alignment.center,
                    child: Text(
                      "سجل الالتزام",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: adherenceFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return AppFetchStateView(
                          error: snapshot.error!,
                          onRetry: _reloadAll,
                        );
                      }

                      final all = snapshot.data ?? [];
                      final view = _filterAndSortForView(all);
                      return _buildTimeList(view);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // -------------------------------
    // DOCTOR VIEW
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

              if (snapshot.hasError) {
                return AppFetchStateView(
                  error: snapshot.error!,
                  onRetry: _reloadAll,
                );
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
