import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/appointments_service.dart';
import '../../../utils/ui_helpers.dart';

class DoctorAbsencesScreen extends StatefulWidget {
  const DoctorAbsencesScreen({super.key});

  @override
  State<DoctorAbsencesScreen> createState() => _DoctorAbsencesScreenState();
}

class _DoctorAbsencesScreenState extends State<DoctorAbsencesScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loading = true;
  String? errorMessage;

  List<DoctorAbsenceDto> absences = const [];

  @override
  void initState() {
    super.initState();
    fetchAbsences();
  }

  Future<void> fetchAbsences() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await appointmentsService.fetchDoctorAbsences();
      data.sort((a, b) => b.startTime.compareTo(a.startTime));

      if (!mounted) return;
      setState(() {
        absences = data;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);

      setState(() {
        loading = false;
        errorMessage = mapHttpErrorToArabicMessage(
          statusCode: e.statusCode,
          data: body,
        );
      });
    } catch (_) {
      if (!mounted) return;

      const msg = 'حدث خطأ غير متوقع. حاول مرة أخرى لاحقًا.';
      showAppErrorSnackBar(context, msg);

      setState(() {
        loading = false;
        errorMessage = msg;
      });
    }
  }

  String _fmtDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  String _typeLabel(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'planned') return 'مخطط';
    if (v == 'emergency') return 'طارئ';
    return raw;
  }

  String? extractAbsenceConflictMessage(Object? body) {
    try {
      if (body is Map<String, dynamic>) {
        final detail = body['detail'];
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is String && first.trim().isNotEmpty) return first.trim();
        }
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
      }
    } catch (_) {}
    return null;
  }

  String _fmtShortLocal(DateTime dt) {
    final d = dt.toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  Future<void> _showEmergencyResultDialog(EmergencyAbsenceResultDto res) async {
    final cancelledCount = res.cancelledAppointments.length;
    final tokensCount = res.tokensIssuedForPatients.length;
    final expiresText = _fmtShortLocal(res.tokenExpiresAt);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          title: const Text('تم إنشاء غياب طارئ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم إلغاء $cancelledCount مواعيد ضمن فترة الغياب.'),
              const SizedBox(height: 6),
              Text('تم إصدار أولوية إعادة حجز لـ $tokensCount مرضى.'),
              const SizedBox(height: 6),
              Text('تنتهي صلاحية الأولوية بتاريخ: $expiresText'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<DoctorAbsenceDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DoctorAbsenceDialog(),
    );

    if (!mounted) return;
    if (result == null) return;

    await createAbsence(result);
  }

  Future<void> _openEditDialog(DoctorAbsenceDto existing) async {
    // سياسة بسيطة وواضحة:
    // - الغياب الطارئ لا نعدّله (إنشاؤه عبر endpoint خاص + آثار جانبية)
    // - يمكن حذفه ثم إنشاء غياب طارئ جديد إذا لزم.
    if (existing.type.trim().toLowerCase() == 'emergency') {
      showAppSnackBar(
        context,
        'لا يمكن تعديل الغياب الطارئ. يمكنك حذفه ثم إنشاء غياب طارئ جديد.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final result = await showDialog<DoctorAbsenceDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DoctorAbsenceDialog(initial: existing),
    );

    if (!mounted) return;
    if (result == null) return;

    await updateAbsence(existing.id, result);
  }

  Future<void> createAbsence(DoctorAbsenceDialogResult input) async {
    final isEmergency = input.type.trim().toLowerCase() == 'emergency';

    // تحذير/تأكيد إضافي للطارئ لأن له آثار جانبية
    if (isEmergency) {
      final confirm = await showConfirmDialog(
        context,
        title: 'تأكيد غياب طارئ',
        message:
            'تنبيه: الغياب الطارئ قد يؤدي إلى إلغاء المواعيد الواقعة ضمن الفترة '
            'وإصدار أولوية إعادة حجز للمرضى المتأثرين.\n\nهل تريد المتابعة؟',
        confirmText: 'تأكيد',
        cancelText: 'تراجع',
        danger: true,
      );

      if (!mounted) return;
      if (!confirm) return;
    }

    try {
      if (isEmergency) {
        // نرسل UTC ISO لتفادي أي التباس بالمناطق الزمنية
        final startIso = input.start.toUtc().toIso8601String();
        final endIso = input.end.toUtc().toIso8601String();
        final notes = input.notes.trim().isEmpty ? null : input.notes.trim();

        final res = await appointmentsService.createEmergencyAbsence(
          startTimeIso: startIso,
          endTimeIso: endIso,
          notes: notes,
        );

        if (!mounted) return;

        // بدل SnackBar: Dialog مع OK
        await _showEmergencyResultDialog(res);

        // تحديث القائمة بعد الإغلاق
        await fetchAbsences();
        return;
      }

      // planned (المنطق الحالي يبقى كما هو)
      await appointmentsService.createDoctorAbsence(
        payload: {
          "start_time": input.start.toIso8601String(),
          "end_time": input.end.toIso8601String(),
          "type": input.type,
          "notes": input.notes,
        },
      );

      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تمت إضافة الغياب.');
      await fetchAbsences();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);

      final msg = extractAbsenceConflictMessage(body);
      if (msg != null) showAppErrorSnackBar(context, msg);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء الإضافة.');
    }
  }

  Future<void> updateAbsence(int id, DoctorAbsenceDialogResult input) async {
    // سياسة: التعديل فقط للـ planned
    final isEmergency = input.type.trim().toLowerCase() == 'emergency';
    if (isEmergency) {
      showAppSnackBar(
        context,
        'لا يمكن تعديل الغياب الطارئ. احذفه ثم أنشئ غيابًا طارئًا جديدًا.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    try {
      await appointmentsService.updateDoctorAbsence(
        absenceId: id,
        payload: {
          "start_time": input.start.toIso8601String(),
          "end_time": input.end.toIso8601String(),
          "type": input.type,
          "notes": input.notes,
        },
      );

      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تم تحديث الغياب.');
      await fetchAbsences();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);

      final msg = extractAbsenceConflictMessage(body);
      if (msg != null) showAppErrorSnackBar(context, msg);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء التحديث.');
    }
  }

  Future<void> deleteAbsence(DoctorAbsenceDto a) async {
    final isEmergency = a.type.trim().toLowerCase() == 'emergency';

    final confirm = await showConfirmDialog(
      context,
      title: 'حذف الغياب',
      message:
          isEmergency
              ? 'هل أنت متأكد من حذف هذا الغياب الطارئ؟'
              : 'هل أنت متأكد من حذف هذا الغياب؟',
      confirmText: 'حذف',
      cancelText: 'تراجع',
      danger: true,
    );

    if (!mounted) return;
    if (!confirm) return;

    try {
      await appointmentsService.deleteDoctorAbsence(absenceId: a.id);
      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تم حذف الغياب.');
      await fetchAbsences();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);

      final msg = extractAbsenceConflictMessage(body);
      if (msg != null) showAppErrorSnackBar(context, msg);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء الحذف.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('غيابات الطبيب'),
          centerTitle: true,
          automaticallyImplyLeading: true,
          backgroundColor: cs.surface,
          foregroundColor: cs.onSurface,
          scrolledUnderElevation: 0,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: fetchAbsences,
              icon: const Icon(Icons.refresh),
            ),
          ],
          leading: IconButton(
            tooltip: 'رجوع',
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة غياب'),
        ),
        body: SafeArea(
          child: Builder(
            builder: (_) {
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (errorMessage != null) {
                return Center(child: Text(errorMessage!));
              }

              return RefreshIndicator(
                onRefresh: fetchAbsences,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                  children: [
                    Text(
                      'تؤثر الغيابات على الحجز وتوليد المواعيد المتاحة (Slots).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (absences.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: Text('لا توجد غيابات حالياً.'),
                        ),
                      )
                    else
                      ...absences.map((a) {
                        final notes = (a.notes ?? '').trim();
                        final type = a.type.trim().toLowerCase();
                        final isEmergency = type == 'emergency';

                        final subtitle =
                            'من: ${_fmtDateTime(a.startTime)}\n'
                            'إلى: ${_fmtDateTime(a.endTime)}\n'
                            'النوع: ${_typeLabel(a.type)}'
                            '${notes.isNotEmpty ? "\nملاحظات: $notes" : ""}'
                            '${isEmergency ? "\nتنبيه: الغياب الطارئ قد يلغي مواعيد ضمن الفترة." : ""}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            elevation: 0,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    isEmergency
                                        ? cs.error.withValues(alpha: 0.10)
                                        : cs.primary.withValues(alpha: 0.10),
                                foregroundColor:
                                    isEmergency ? cs.error : cs.primary,
                                child: Icon(
                                  isEmergency
                                      ? Icons.warning_amber
                                      : Icons.event_busy,
                                ),
                              ),
                              title: Text(
                                isEmergency ? 'غياب طارئ' : 'غياب',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(subtitle),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await _openEditDialog(a);
                                  }
                                  if (v == 'delete') {
                                    await deleteAbsence(a);
                                  }
                                },
                                itemBuilder: (_) {
                                  if (isEmergency) {
                                    return const [
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('حذف'),
                                      ),
                                    ];
                                  }
                                  return const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('تعديل'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('حذف'),
                                    ),
                                  ];
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ---------------- Dialog ----------------

class DoctorAbsenceDialogResult {
  final DateTime start;
  final DateTime end;
  final String type;
  final String notes;

  DoctorAbsenceDialogResult({
    required this.start,
    required this.end,
    required this.type,
    required this.notes,
  });
}

class DoctorAbsenceDialog extends StatefulWidget {
  final DoctorAbsenceDto? initial;

  const DoctorAbsenceDialog({super.key, this.initial});

  @override
  State<DoctorAbsenceDialog> createState() => _DoctorAbsenceDialogState();
}

class _DoctorAbsenceDialogState extends State<DoctorAbsenceDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  late DateTime _start;
  late DateTime _end;
  String _type = 'planned';

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    if (widget.initial != null) {
      _start = widget.initial!.startTime.toLocal();
      _end = widget.initial!.endTime.toLocal();
      _type = widget.initial!.type;
      _notesController.text = (widget.initial!.notes ?? '');
    } else {
      _start = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour,
        (now.minute ~/ 5) * 5,
      );
      _end = _start.add(const Duration(minutes: 30));
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted) return null;
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (!mounted) return null;
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_start.isAfter(_end) || _start.isAtSameMomentAs(_end)) {
      showAppErrorSnackBar(context, 'يجب أن يكون وقت البداية قبل وقت النهاية.');
      return;
    }

    Navigator.of(context).pop(
      DoctorAbsenceDialogResult(
        start: _start,
        end: _end,
        type: _type,
        notes: _notesController.text.trim(),
      ),
    );
  }

  String _fmtDialogDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final cs = Theme.of(context).colorScheme;

    final isEmergency = _type.trim().toLowerCase() == 'emergency';

    return AlertDialog(
      title: Text(isEdit ? 'تعديل غياب' : 'إضافة غياب'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('وقت البداية'),
                subtitle: Text(_fmtDialogDateTime(_start)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final picked = await _pickDateTime(_start);
                  if (!mounted) return;
                  if (picked == null) return;

                  setState(() {
                    _start = picked;
                    if (!_end.isAfter(_start)) {
                      _end = _start.add(const Duration(minutes: 30));
                    }
                  });
                },
              ),

              const SizedBox(height: 8),

              // End
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('وقت النهاية'),
                subtitle: Text(_fmtDialogDateTime(_end)),
                trailing: const Icon(Icons.edit_calendar),
                onTap: () async {
                  final picked = await _pickDateTime(_end);
                  if (!mounted) return;
                  if (picked == null) return;

                  setState(() {
                    _end = picked;
                  });
                },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'النوع',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'planned', child: Text('مخطط')),
                  DropdownMenuItem(value: 'emergency', child: Text('طارئ')),
                ],
                onChanged:
                    isEdit
                        ? null
                        : (v) => setState(() => _type = v ?? 'planned'),
              ),

              if (!isEdit && isEmergency) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, color: cs.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تنبيه: عند اختيار "طارئ" سيتم إلغاء المواعيد الواقعة ضمن الفترة، '
                          'وسيتم منح المرضى المتأثرين أولوية إعادة حجز مؤقتة.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurface, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
                validator: (_) => null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: Text(isEdit ? 'حفظ' : 'إضافة')),
      ],
    );
  }
}
