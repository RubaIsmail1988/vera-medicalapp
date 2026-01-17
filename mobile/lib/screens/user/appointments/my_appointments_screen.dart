import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../../models/appointment.dart';
import '../../../services/appointments_service.dart';
import '../../../utils/ui_helpers.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loading = true;
  String? errorMessage;

  // Role from prefs: patient | doctor
  String role = 'patient';

  // Server-side filters
  String statusFilter =
      'all'; // all | pending | confirmed | cancelled | no_show

  // time filter supported by backend: upcoming | past | all
  String timeFilter = 'upcoming';

  // preset supported by backend: today | next7 | day
  String? datePreset; // null | today | next7 | day
  String? presetDay; // YYYY-MM-DD (only when datePreset == 'day')

  // legacy/optional (keep, but we won’t use it in UI now)
  String? fromDate; // YYYY-MM-DD
  String? toDate; // YYYY-MM-DD

  List<Appointment> appointments = const [];

  @override
  void initState() {
    super.initState();
    _loadRoleAndFetch();
  }

  Future<void> _loadRoleAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString('user_role') ?? 'patient';
    await fetch();
  }

  String fmtYmd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  String _normStatus(String raw) => raw.trim().toLowerCase();

  String _statusLabel(String raw) {
    switch (_normStatus(raw)) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'no_show':
        return 'لم يحضر';
      default:
        return raw;
    }
  }

  IconData _statusIcon(String raw) {
    switch (_normStatus(raw)) {
      case 'pending':
        return Icons.hourglass_top;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'no_show':
        return Icons.do_not_disturb_alt_outlined;
      default:
        return Icons.info_outline;
    }
  }

  bool _isMoreThanOneHourBeforeStart(Appointment a) {
    final now = DateTime.now();
    final startLocal = a.dateTime.toLocal();
    final cutoff = startLocal.subtract(const Duration(hours: 1));
    return now.isBefore(cutoff);
  }

  bool _canCancel(Appointment a) {
    final s = _normStatus(a.status);

    if (s == 'no_show') return false;
    if (s == 'cancelled') return false;

    final isCancelableStatus = s == 'pending' || s == 'confirmed';
    if (!isCancelableStatus) return false;

    if (a.hasAnyOrders) return false;

    if (role == 'patient') {
      return _isMoreThanOneHourBeforeStart(a);
    }

    return true;
  }

  bool _canMarkNoShow(Appointment a) {
    if (role != 'doctor') return false;

    final s = _normStatus(a.status);
    if (s == 'cancelled' || s == 'no_show') return false;

    if (s != 'confirmed') return false;

    if (a.hasAnyOrders) return false;

    final now = DateTime.now();
    final endTime = a.dateTime.toLocal().add(
      Duration(minutes: a.durationMinutes),
    );

    return endTime.isBefore(now);
  }

  bool _canConfirm(Appointment a) {
    if (role != 'doctor') return false;
    return _normStatus(a.status) == 'pending';
  }

  String _fmtDateTime(DateTime dtUtcOrZ) {
    final local = dtUtcOrZ.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  String _emptyLabelByFilters() {
    final hasStatus = statusFilter != 'all';

    String timePart;
    if (timeFilter == 'past') {
      timePart = 'سابقة';
    } else if (timeFilter == 'upcoming') {
      timePart = 'قادمة';
    } else {
      timePart = 'حالياً';
    }

    String datePart = '';
    if (datePreset == 'today') datePart = ' لليوم';
    if (datePreset == 'next7') datePart = ' للأسبوع القادم';
    if (datePreset == 'day' && presetDay != null) datePart = ' ليوم $presetDay';

    final statusPart = hasStatus ? ' بهذه الحالة' : '';
    return 'لا توجد مواعيد $timePart$statusPart$datePart.';
  }

  void _sortAppointmentsInPlace(List<Appointment> data) {
    if (timeFilter == 'upcoming') {
      data.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return;
    }
    if (timeFilter == 'past') {
      data.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      return;
    }
    data.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  Future<void> fetch() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await appointmentsService.fetchMyAppointments(
        status: statusFilter == 'all' ? null : statusFilter,
        time: timeFilter,
        preset: datePreset,
        date: presetDay,
        fromDate: fromDate,
        toDate: toDate,
      );

      _sortAppointmentsInPlace(data);

      if (!mounted) return;
      setState(() {
        appointments = data;
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

  Future<void> _cancel(Appointment a) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'إلغاء الموعد',
      message: 'هل أنت متأكد من إلغاء هذا الموعد؟',
      confirmText: 'إلغاء الموعد',
      cancelText: 'تراجع',
      danger: true,
    );

    if (!mounted) return;
    if (!confirm) return;

    try {
      await appointmentsService.cancelAppointment(appointmentId: a.id);
      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تم إلغاء الموعد.');
      await fetch();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء الإلغاء.');
    }
  }

  Future<void> _markNoShow(Appointment a) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'تحديد كـ لم يحضر',
      message: 'هل تريد وضع هذا الموعد على أنه لم يحضر؟',
      confirmText: 'تأكيد',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!mounted) return;
    if (!confirm) return;

    try {
      await appointmentsService.markNoShow(appointmentId: a.id);
      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تم تحديث الحالة إلى لم يحضر.');
      await fetch();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء تحديث الحالة.');
    }
  }

  Future<void> _confirm(Appointment a) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'تأكيد الموعد',
      message: 'هل تريد تأكيد هذا الموعد؟',
      confirmText: 'تأكيد',
      cancelText: 'تراجع',
      danger: false,
    );

    if (!mounted) return;
    if (!confirm) return;

    try {
      await appointmentsService.confirmAppointment(appointmentId: a.id);
      if (!mounted) return;
      showAppSuccessSnackBar(context, 'تم تأكيد الموعد.');
      await fetch();
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع أثناء التأكيد.');
    }
  }

  void _openRecordForAppointment(Appointment a) {
    if (!mounted) return;

    final appointmentId = a.id;
    if (appointmentId <= 0) return;

    if (role == 'doctor') {
      final patientId = a.patient;
      if (patientId <= 0) {
        showAppSnackBar(
          context,
          'تعذر فتح الإضبارة: patientId غير متوفر.',
          type: AppSnackBarType.error,
        );
        return;
      }

      context.go(
        '/app/record?role=doctor&patientId=$patientId&appointmentId=$appointmentId',
      );
      return;
    }

    context.go('/app/record?role=patient&appointmentId=$appointmentId');
  }

  Future<void> _setStatusFilter(String v) async {
    if (!mounted) return;
    setState(() => statusFilter = v);
    await fetch();
  }

  Future<void> _setTimeFilter(String v) async {
    if (!mounted) return;

    setState(() {
      timeFilter = v;

      if (timeFilter == 'past' && datePreset == 'next7') {
        datePreset = null;
        presetDay = null;
        fromDate = null;
        toDate = null;
      }
    });

    await fetch();
  }

  Future<void> _setToday() async {
    if (!mounted) return;
    setState(() {
      datePreset = 'today';
      presetDay = null;
      fromDate = null;
      toDate = null;
    });
    await fetch();
  }

  Future<void> _setNext7() async {
    if (!mounted) return;
    if (timeFilter == 'past') return;

    setState(() {
      datePreset = 'next7';
      presetDay = null;
      fromDate = null;
      toDate = null;
    });
    await fetch();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();

    final DateTime firstDate;
    final DateTime lastDate;

    if (timeFilter == 'past') {
      firstDate = now.subtract(const Duration(days: 365));
      lastDate = now;
    } else if (timeFilter == 'upcoming') {
      firstDate = now;
      lastDate = now.add(const Duration(days: 365));
    } else {
      firstDate = now.subtract(const Duration(days: 365));
      lastDate = now.add(const Duration(days: 365));
    }

    final initialDate =
        now.isBefore(firstDate)
            ? firstDate
            : (now.isAfter(lastDate) ? lastDate : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (!mounted) return;
    if (picked == null) return;

    final ymd = fmtYmd(picked);
    setState(() {
      datePreset = 'day';
      presetDay = ymd;
      fromDate = null;
      toDate = null;
    });
    await fetch();
  }

  Future<void> _clearDateFilter() async {
    if (!mounted) return;
    setState(() {
      datePreset = null;
      presetDay = null;
      fromDate = null;
      toDate = null;
    });
    await fetch();
  }

  String _timeLabel(String v) {
    switch (v) {
      case 'upcoming':
        return 'القادمة';
      case 'past':
        return 'السابقة';
      case 'all':
        return 'الكل';
      default:
        return v;
    }
  }

  String _dateFilterLabel() {
    if (datePreset == null) return 'بدون فلترة تاريخ';
    if (datePreset == 'today') return 'اليوم';
    if (datePreset == 'next7') return 'الأسبوع القادم';
    if (datePreset == 'day' && presetDay != null) return 'يوم: $presetDay';
    return 'فلترة تاريخ';
  }

  String _statusChipLabel(String v) {
    switch (v) {
      case 'all':
        return 'الكل';
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'no_show':
        return 'لم يحضر';
      default:
        return v;
    }
  }

  // -----------------------------
  // Triage chips builders
  // -----------------------------
  List<String> _buildPatientTriageChips(Appointment a) {
    if (role != 'patient') return const [];
    final t = a.triage;
    if (t == null) return const [];

    final items = <String>[];

    final symptoms = (t.symptomsText ?? '').trim();
    if (symptoms.isNotEmpty) items.add('الأعراض: $symptoms');

    final temp = (t.temperatureC ?? '').trim();
    if (temp.isNotEmpty) items.add('الحرارة: $temp°C');

    if (t.bpSystolic != null && t.bpDiastolic != null) {
      items.add('الضغط: ${t.bpSystolic}/${t.bpDiastolic}');
    }

    if (t.heartRate != null) {
      items.add('النبض: ${t.heartRate} bpm');
    }

    return items;
  }

  List<String> _buildDoctorTriageChips(Appointment a) {
    if (role != 'doctor') return const [];
    final t = a.triage;
    if (t == null) return const [];

    final items = <String>[];

    final symptoms = (t.symptomsText ?? '').trim();
    if (symptoms.isNotEmpty) items.add('الأعراض: $symptoms');

    final temp = (t.temperatureC ?? '').trim();
    if (temp.isNotEmpty) items.add('T: $temp°C');

    if (t.bpSystolic != null && t.bpDiastolic != null) {
      items.add('BP: ${t.bpSystolic}/${t.bpDiastolic}');
    }

    if (t.heartRate != null) items.add('HR: ${t.heartRate}');

    items.add('Score: ${t.score}');
    if (t.confidence != null) items.add('Conf: ${t.confidence}%');

    final missing =
        t.missingFields
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty)
            .toList();
    if (missing.isNotEmpty) items.add('Missing: ${missing.join(", ")}');

    final ver = (t.scoreVersion).trim();
    if (ver.isNotEmpty) items.add(ver);

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Builder(
        builder: (_) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (errorMessage != null) {
            return Center(child: Text(errorMessage!));
          }

          return RefreshIndicator(
            onRefresh: fetch,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        role == 'doctor' ? 'مواعيد المرضى' : 'مواعيدي',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'تحديث',
                      onPressed: fetch,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Text('الوقت', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(_timeLabel('upcoming')),
                      selected: timeFilter == 'upcoming',
                      onSelected: (_) => _setTimeFilter('upcoming'),
                    ),
                    ChoiceChip(
                      label: Text(_timeLabel('past')),
                      selected: timeFilter == 'past',
                      onSelected: (_) => _setTimeFilter('past'),
                    ),
                    ChoiceChip(
                      label: Text(_timeLabel('all')),
                      selected: timeFilter == 'all',
                      onSelected: (_) => _setTimeFilter('all'),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text('الحالة', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(_statusChipLabel('all')),
                      selected: statusFilter == 'all',
                      onSelected: (_) => _setStatusFilter('all'),
                    ),
                    ChoiceChip(
                      label: Text(_statusChipLabel('pending')),
                      selected: statusFilter == 'pending',
                      onSelected: (_) => _setStatusFilter('pending'),
                    ),
                    ChoiceChip(
                      label: Text(_statusChipLabel('confirmed')),
                      selected: statusFilter == 'confirmed',
                      onSelected: (_) => _setStatusFilter('confirmed'),
                    ),
                    ChoiceChip(
                      label: Text(_statusChipLabel('cancelled')),
                      selected: statusFilter == 'cancelled',
                      onSelected: (_) => _setStatusFilter('cancelled'),
                    ),
                    ChoiceChip(
                      label: Text(_statusChipLabel('no_show')),
                      selected: statusFilter == 'no_show',
                      onSelected: (_) => _setStatusFilter('no_show'),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Text('التاريخ', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('اليوم'),
                      selected: datePreset == 'today',
                      onSelected: (_) => _setToday(),
                    ),
                    if (timeFilter != 'past')
                      ChoiceChip(
                        label: const Text('الأسبوع القادم'),
                        selected: datePreset == 'next7',
                        onSelected: (_) => _setNext7(),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.date_range),
                      label: Text(
                        datePreset == 'day' && presetDay != null
                            ? _dateFilterLabel()
                            : (timeFilter == 'past'
                                ? 'اختيار يوم سابق'
                                : timeFilter == 'upcoming'
                                ? 'اختيار يوم قادم'
                                : 'اختيار يوم'),
                      ),
                      onPressed: _pickDay,
                    ),
                    TextButton(
                      onPressed: _clearDateFilter,
                      child: const Text('مسح'),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (appointments.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Text(_emptyLabelByFilters()),
                    ),
                  )
                else
                  ...appointments.map((a) {
                    final typeName =
                        (a.appointmentTypeName ?? 'نوع زيارة').trim();
                    final statusLabel = _statusLabel(a.status);

                    final counterpartLine =
                        role == 'doctor'
                            ? 'المريض: ${(a.patientName ?? 'مريض #${a.patient}').trim()}'
                            : 'الطبيب: ${(a.doctorName ?? 'طبيب #${a.doctor}').trim()}';

                    final notes = (a.notes ?? '').trim();

                    final canCancel = _canCancel(a);
                    final canNoShow = _canMarkNoShow(a);
                    final canConfirm = _canConfirm(a);

                    final title =
                        a.durationMinutes > 0
                            ? '$typeName (${a.durationMinutes} دقيقة)'
                            : typeName;

                    final bool showMenuForDoctor =
                        role == 'doctor' &&
                        (canConfirm || canNoShow || canCancel);

                    Widget trailing;

                    if (role == 'doctor') {
                      trailing = PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'record') _openRecordForAppointment(a);
                          if (v == 'confirm') _confirm(a);
                          if (v == 'no_show') _markNoShow(a);
                          if (v == 'cancel') _cancel(a);
                        },
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'record',
                                child: Text('فتح الإضبارة لهذه الزيارة'),
                              ),
                              if (showMenuForDoctor) ...[
                                if (canConfirm)
                                  const PopupMenuItem(
                                    value: 'confirm',
                                    child: Text('تأكيد'),
                                  ),
                                if (canNoShow)
                                  const PopupMenuItem(
                                    value: 'no_show',
                                    child: Text('لم يحضر'),
                                  ),
                                if (canCancel)
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Text('إلغاء'),
                                  ),
                              ],
                            ],
                      );
                    } else {
                      trailing = PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'record') _openRecordForAppointment(a);
                          if (v == 'cancel') _cancel(a);
                        },
                        itemBuilder:
                            (_) => [
                              const PopupMenuItem(
                                value: 'record',
                                child: Text('فتح الإضبارة'),
                              ),
                              if (canCancel)
                                const PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('إلغاء الموعد'),
                                ),
                            ],
                      );
                    }

                    final patientChips = _buildPatientTriageChips(a);
                    final doctorChips = _buildDoctorTriageChips(a);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(_statusIcon(a.status)),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  counterpartLine,
                                  'الوقت: ${_fmtDateTime(a.dateTime)}',
                                  'الحالة: $statusLabel',
                                  if (notes.isNotEmpty) 'ملاحظات: $notes',
                                ].join('\n'),
                              ),
                              if (role == 'patient' &&
                                  patientChips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text('بيانات الحالة التي أدخلتها:'),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      patientChips
                                          .map((t) => Chip(label: Text(t)))
                                          .toList(),
                                ),
                              ],
                              if (role == 'doctor' &&
                                  doctorChips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const Text('Triage (قبل الزيارة):'),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      doctorChips
                                          .map((t) => Chip(label: Text(t)))
                                          .toList(),
                                ),
                              ],
                            ],
                          ),
                          trailing: trailing,
                          isThreeLine: false,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
