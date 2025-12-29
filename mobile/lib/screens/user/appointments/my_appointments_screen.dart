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
  String? datePreset; // null | today | next7 | day
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

  bool _canCancel(Appointment a) {
    final s = _normStatus(a.status);
    if (s == 'no_show') return false;
    if (s == 'cancelled') return false;
    return true;
  }

  bool _canMarkNoShow(Appointment a) {
    if (role != 'doctor') return false;

    final s = _normStatus(a.status);
    if (s == 'cancelled' || s == 'no_show') return false;

    // do not allow no_show for future appointments
    final now = DateTime.now();
    return a.dateTime.toLocal().isBefore(now);
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

  Future<void> fetch() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final data = await appointmentsService.fetchMyAppointments(
        status: statusFilter == 'all' ? null : statusFilter,
        fromDate: fromDate,
        toDate: toDate,
      );

      data.sort((a, b) => b.dateTime.compareTo(a.dateTime));

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
      title: 'تحديد كـ No Show',
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
      showAppSuccessSnackBar(context, 'تم تحديث الحالة إلى No Show.');
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

  Future<void> _setStatusFilter(String v) async {
    setState(() => statusFilter = v);
    await fetch();
  }

  Future<void> _setToday() async {
    final now = DateTime.now();
    final ymd = fmtYmd(now);
    setState(() {
      datePreset = 'today';
      fromDate = ymd;
      toDate = ymd;
    });
    await fetch();
  }

  Future<void> _setNext7() async {
    final now = DateTime.now();
    setState(() {
      datePreset = 'next7';
      fromDate = fmtYmd(now);
      toDate = fmtYmd(now.add(const Duration(days: 7)));
    });
    await fetch();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted) return;
    if (picked == null) return;

    final ymd = fmtYmd(picked);
    setState(() {
      datePreset = 'day';
      fromDate = ymd;
      toDate = ymd;
    });
    await fetch();
  }

  Future<void> _clearDateFilter() async {
    setState(() {
      datePreset = null;
      fromDate = null;
      toDate = null;
    });
    await fetch();
  }

  @override
  Widget build(BuildContext context) {
    final showBookButton = role == 'patient';

    return Scaffold(
      floatingActionButton:
          showBookButton
              ? FloatingActionButton.extended(
                // مهم: ليس لديك route باسم /app/appointments/book بدون doctorId
                // الموجود هو /app/appointments (ثم داخلها حجز/بحث طبيب)
                onPressed: () => context.go('/app/appointments'),
                icon: const Icon(Icons.add),
                label: const Text('حجز موعد'),
              )
              : null,
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
              onRefresh: fetch,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
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

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('الكل'),
                        selected: statusFilter == 'all',
                        onSelected: (_) => _setStatusFilter('all'),
                      ),
                      ChoiceChip(
                        label: const Text('Pending'),
                        selected: statusFilter == 'pending',
                        onSelected: (_) => _setStatusFilter('pending'),
                      ),
                      ChoiceChip(
                        label: const Text('Confirmed'),
                        selected: statusFilter == 'confirmed',
                        onSelected: (_) => _setStatusFilter('confirmed'),
                      ),
                      ChoiceChip(
                        label: const Text('Cancelled'),
                        selected: statusFilter == 'cancelled',
                        onSelected: (_) => _setStatusFilter('cancelled'),
                      ),
                      ChoiceChip(
                        label: const Text('No Show'),
                        selected: statusFilter == 'no_show',
                        onSelected: (_) => _setStatusFilter('no_show'),
                      ),
                    ],
                  ),

                  if (role == 'doctor') ...[
                    const SizedBox(height: 10),
                    Text(
                      'فلترة حسب التاريخ',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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
                        ChoiceChip(
                          label: const Text('الأسبوع القادم'),
                          selected: datePreset == 'next7',
                          onSelected: (_) => _setNext7(),
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.date_range),
                          label: Text(
                            datePreset == 'day' && fromDate != null
                                ? 'اليوم: $fromDate'
                                : 'اختيار يوم',
                          ),
                          onPressed: _pickDay,
                        ),
                        TextButton(
                          onPressed: _clearDateFilter,
                          child: const Text('مسح'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  if (appointments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Text('لا توجد مواعيد حالياً.'),
                      ),
                    )
                  else
                    ...appointments.map((a) {
                      final typeName =
                          (a.appointmentTypeName ??
                                  'Type #${a.appointmentType}')
                              .trim();

                      final statusLabel = _statusLabel(a.status);

                      final counterpartLine =
                          role == 'doctor'
                              ? 'المريض: ${(a.patientName ?? 'Patient #${a.patient}').trim()}'
                              : 'الطبيب: ${(a.doctorName ?? 'Doctor #${a.doctor}').trim()}';

                      final notes = (a.notes ?? '').trim();

                      final canCancel = _canCancel(a);
                      final canNoShow = _canMarkNoShow(a);
                      final canConfirm = _canConfirm(a);

                      Widget? trailing;

                      if (role == 'doctor' &&
                          (canConfirm || canNoShow || canCancel)) {
                        trailing = PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'confirm') _confirm(a);
                            if (v == 'no_show') _markNoShow(a);
                            if (v == 'cancel') _cancel(a);
                          },
                          itemBuilder:
                              (_) => [
                                if (canConfirm)
                                  const PopupMenuItem(
                                    value: 'confirm',
                                    child: Text('تأكيد'),
                                  ),
                                if (canNoShow)
                                  const PopupMenuItem(
                                    value: 'no_show',
                                    child: Text('No Show'),
                                  ),
                                if (canCancel)
                                  const PopupMenuItem(
                                    value: 'cancel',
                                    child: Text('إلغاء'),
                                  ),
                              ],
                        );
                      } else if (role == 'patient' && canCancel) {
                        trailing = TextButton(
                          onPressed: () => _cancel(a),
                          child: const Text('إلغاء'),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 0,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(_statusIcon(a.status)),
                            ),
                            title: Text(
                              typeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '$counterpartLine\n'
                              'الوقت: ${_fmtDateTime(a.dateTime)}\n'
                              'الحالة: $statusLabel'
                              '${notes.isNotEmpty ? "\nملاحظات: $notes" : ""}',
                            ),
                            trailing: trailing,
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
    );
  }
}
