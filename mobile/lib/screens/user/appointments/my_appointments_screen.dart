import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '/models/appointment.dart';
import '/services/appointments_service.dart';
import '/utils/ui_helpers.dart';
import '/utils/api_exception.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loading = true;

  // Fetch error (INLINE ONLY)
  Object? fetchError;

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

  bool _isPastAppointment(Appointment a) {
    final now = DateTime.now();
    final endTime = a.dateTime.toLocal().add(
      Duration(minutes: a.durationMinutes),
    );
    return endTime.isBefore(now);
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

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  String _fmtTime(DateTime dt) {
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$hh:$min';
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

  // ---------------------------------------------------------------------------
  // Fetch (INLINE only on error)
  // ---------------------------------------------------------------------------

  Future<void> fetch() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      fetchError = null;
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
        fetchError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      // Fetch -> INLINE ONLY (no SnackBar)
      setState(() {
        loading = false;
        fetchError = _FetchHttpException(e.statusCode, body);
      });
    } catch (e) {
      if (!mounted) return;

      // Fetch -> INLINE ONLY (no SnackBar)
      setState(() {
        loading = false;
        fetchError = e;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Actions (SnackBar allowed)
  // ---------------------------------------------------------------------------
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
      case 'all':
        return 'الكل';
      case 'upcoming':
        return 'القادمة';
      case 'past':
        return 'السابقة';
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
        return 'انتظار';
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
  // Triage helpers
  // -----------------------------
  String _triageSymptomsText(Appointment a) {
    final t = a.triage;
    if (t == null) return '';
    return (t.symptomsText ?? '').trim();
  }

  List<String> _buildPatientVitalsChips(Appointment a) {
    if (role != 'patient') return const [];
    final t = a.triage;
    if (t == null) return const [];

    final items = <String>[];

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

  List<String> _buildDoctorVitalsChips(Appointment a) {
    if (role != 'doctor') return const [];
    final t = a.triage;
    if (t == null) return const [];

    final items = <String>[];

    final temp = (t.temperatureC ?? '').trim();
    if (temp.isNotEmpty) items.add('T: $temp°C');

    if (t.bpSystolic != null && t.bpDiastolic != null) {
      items.add('BP: ${t.bpSystolic}/${t.bpDiastolic}');
    }

    if (t.heartRate != null) {
      items.add('HR: ${t.heartRate}');
    }

    return items;
  }

  String _doctorScoreLine(Appointment a) {
    final t = a.triage;
    if (t == null) return '';
    return 'Score: ${t.score}';
  }

  String _doctorConfidenceLine(Appointment a) {
    final t = a.triage;
    if (t == null) return '';
    if (t.confidence == null) return '';
    return 'Conf: ${t.confidence}%';
  }

  List<String> _doctorMissingFields(Appointment a) {
    final t = a.triage;
    if (t == null) return const [];
    return t.missingFields
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _doctorModelVersion(Appointment a) {
    final t = a.triage;
    if (t == null) return '';
    return (t.scoreVersion).trim();
  }

  bool _shouldShowDoctorTriageBlock(Appointment a) {
    if (role != 'doctor') return false;
    final t = a.triage;
    if (t == null) return false;

    final symptoms = _triageSymptomsText(a);
    final vitals = _buildDoctorVitalsChips(a);
    final scoreLine = _doctorScoreLine(a);
    final confLine = _doctorConfidenceLine(a);
    final missing = _doctorMissingFields(a);
    final model = _doctorModelVersion(a);

    return symptoms.isNotEmpty ||
        vitals.isNotEmpty ||
        scoreLine.isNotEmpty ||
        confLine.isNotEmpty ||
        missing.isNotEmpty ||
        model.isNotEmpty;
  }

  Widget _rtlSectionTitle(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _chipsWrap(List<String> chips) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: chips.map((t) => Chip(label: Text(t))).toList(),
    );
  }

  Widget _symptomsBlock(BuildContext context, String title, String symptoms) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              symptoms,
              textAlign: TextAlign.right,
              softWrap: true,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doctorMissingBlock(BuildContext context, List<String> missing) {
    if (missing.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'الحقول الناقصة:',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              missing.join('، '),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // Priority badge helpers
  // -----------------------------
  String _fmtDateTimeShort(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min';
  }

  Widget _priorityBadgeChip(BuildContext context, Appointment a) {
    final b = a.priorityBadge;
    if (b == null) return const SizedBox.shrink();
    if (!b.isRebookingPriority) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    final expires = b.expiresAt;
    final expiresLabel =
        (expires != null) ? 'تنتهي: ${_fmtDateTimeShort(expires)}' : null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        Chip(
          avatar: Icon(Icons.bolt, size: 18, color: cs.onSurface),
          label: const Text('أولوية إعادة الحجز'),
        ),
        if (expiresLabel != null) Chip(label: Text(expiresLabel)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inline fetch error state
    if (!loading && fetchError != null) {
      final st = mapFetchExceptionToInlineState(fetchError!);
      return SafeArea(
        child: AppInlineErrorState(
          title: st.title,
          message: st.message,
          icon: st.icon,
          onRetry: fetch,
        ),
      );
    }

    return SafeArea(
      child: Builder(
        builder: (_) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
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
                        textAlign: TextAlign.right,
                      ),
                    ),

                    // Doctor urgent requests shortcut
                    if (role == 'doctor')
                      TextButton.icon(
                        onPressed: () {
                          context.go('/app/appointments/urgent-requests');
                        },
                        icon: const Icon(Icons.priority_high),
                        label: const Text('الطلبات العاجلة'),
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
                      child: const Text('مسح تصفية التاريخ'),
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
                    final status = _normStatus(a.status);
                    final statusLabel = _statusLabel(a.status);

                    final counterpartLine =
                        role == 'doctor'
                            ? 'المريض: ${(a.patientName ?? 'مريض #${a.patient}').trim()}'
                            : 'الطبيب: ${(a.doctorName ?? 'طبيب #${a.doctor}').trim()}';

                    final notes = (a.notes ?? '').trim();

                    final isPast = _isPastAppointment(a);

                    // Base permissions
                    final canCancelBase = _canCancel(a);
                    final canNoShow = _canMarkNoShow(a);
                    final canConfirmBase = _canConfirm(a);

                    // -----------------------------
                    // ACTION RULES (as requested)
                    // -----------------------------

                    // Cancelled: no record
                    // No_show: hide ⋮ too => no actions
                    // Pending & past: hide confirm/cancel/record
                    // Confirmed & past: remove cancel
                    final canOpenRecord =
                        (status != 'cancelled') &&
                        (status != 'no_show') &&
                        !(status == 'pending' && isPast);

                    final canConfirm =
                        canConfirmBase && !(status == 'pending' && isPast);

                    final canCancel =
                        canCancelBase &&
                        !isPast && // if time passed -> no cancel for both
                        status != 'no_show' &&
                        status != 'cancelled' &&
                        !(status == 'confirmed' && isPast);

                    // If pending and past -> we already blocked cancel via isPast
                    // If confirmed and past -> blocked via isPast as well

                    final hasAnyAction =
                        role == 'doctor'
                            ? (canOpenRecord ||
                                canConfirm ||
                                canNoShow ||
                                canCancel)
                            : (canOpenRecord || canCancel);

                    final title =
                        a.durationMinutes > 0
                            ? '$typeName (${a.durationMinutes} دقيقة)'
                            : typeName;

                    // Keep layout stable even when ⋮ hidden
                    final Widget trailing =
                        hasAnyAction
                            ? PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'record') _openRecordForAppointment(a);
                                if (v == 'confirm') _confirm(a);
                                if (v == 'no_show') _markNoShow(a);
                                if (v == 'cancel') _cancel(a);
                              },
                              itemBuilder:
                                  (_) => [
                                    if (canOpenRecord)
                                      const PopupMenuItem(
                                        value: 'record',
                                        child: Text('فتح الإضبارة'),
                                      ),
                                    if (role == 'doctor' && canConfirm)
                                      const PopupMenuItem(
                                        value: 'confirm',
                                        child: Text('تأكيد'),
                                      ),
                                    if (role == 'doctor' && canNoShow)
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
                            )
                            : const SizedBox(width: 40);

                    // -----------------------------
                    // Triage blocks
                    // -----------------------------
                    final symptoms = _triageSymptomsText(a);
                    final patientVitals = _buildPatientVitalsChips(a);
                    final doctorVitals = _buildDoctorVitalsChips(a);

                    final scoreLine = _doctorScoreLine(a);
                    final confLine = _doctorConfidenceLine(a);
                    final missing = _doctorMissingFields(a);
                    final model = _doctorModelVersion(a);

                    final showDoctorTriage = _shouldShowDoctorTriageBlock(a);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        elevation: 0,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(_statusIcon(a.status)),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  [
                                    counterpartLine,
                                    'التاريخ: ${_fmtDate(a.dateTime)}',
                                    'الوقت: ${_fmtTime(a.dateTime)}',
                                    'الحالة: $statusLabel',
                                    if (notes.isNotEmpty) 'ملاحظات: $notes',
                                  ].join('\n'),
                                  textAlign: TextAlign.right,
                                ),

                                // Priority badge
                                if (a.priorityBadge?.isRebookingPriority ==
                                    true) ...[
                                  const SizedBox(height: 10),
                                  _rtlSectionTitle(context, 'ميزة:'),
                                  const SizedBox(height: 6),
                                  _priorityBadgeChip(context, a),
                                ],

                                // Patient symptoms
                                if (symptoms.isNotEmpty &&
                                    role == 'patient') ...[
                                  const SizedBox(height: 10),
                                  _symptomsBlock(
                                    context,
                                    'الأعراض التي أدخلتها:',
                                    symptoms,
                                  ),
                                ],

                                // Doctor symptoms
                                if (symptoms.isNotEmpty &&
                                    role == 'doctor') ...[
                                  const SizedBox(height: 10),
                                  _symptomsBlock(context, 'الأعراض:', symptoms),
                                ],

                                // Patient vitals
                                if (role == 'patient' &&
                                    patientVitals.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  _rtlSectionTitle(context, 'بيانات أخرى:'),
                                  const SizedBox(height: 6),
                                  _chipsWrap(patientVitals),
                                ],

                                // Doctor triage block (ONLY if exists)
                                if (role == 'doctor' && showDoctorTriage) ...[
                                  if (doctorVitals.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _rtlSectionTitle(
                                      context,
                                      'المؤشرات الحيوية:',
                                    ),
                                    const SizedBox(height: 6),
                                    _chipsWrap(doctorVitals),
                                  ],

                                  if (scoreLine.isNotEmpty ||
                                      confLine.isNotEmpty ||
                                      missing.isNotEmpty ||
                                      model.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _rtlSectionTitle(
                                      context,
                                      'تقييم الحالة: قبل الزيارة',
                                    ),
                                    const SizedBox(height: 6),
                                    _chipsWrap([
                                      if (scoreLine.isNotEmpty) scoreLine,
                                      if (confLine.isNotEmpty) confLine,
                                    ]),
                                    if (missing.isNotEmpty)
                                      _doctorMissingBlock(context, missing),
                                    if (model.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      _rtlSectionTitle(context, 'النموذج:'),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Chip(label: Text(model)),
                                      ),
                                    ],
                                  ],
                                ],
                              ],
                            ),
                            trailing: trailing,
                            isThreeLine: false,
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
    );
  }
}

// Local wrapper so mapFetchExceptionToInlineState can interpret HTTP-ish errors.
// NOTE: This is for fetch only. Actions still use SnackBars.
class _FetchHttpException implements Exception {
  final int statusCode;
  final Object? data;

  _FetchHttpException(this.statusCode, this.data);

  @override
  String toString() => 'HTTP $statusCode';
}
