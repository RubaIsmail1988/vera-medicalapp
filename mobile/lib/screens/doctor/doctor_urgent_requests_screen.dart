import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/appointments_service.dart';
import '/utils/ui_helpers.dart';

class DoctorUrgentRequestsScreen extends StatefulWidget {
  const DoctorUrgentRequestsScreen({super.key});

  @override
  State<DoctorUrgentRequestsScreen> createState() =>
      _DoctorUrgentRequestsScreenState();
}

class _DoctorUrgentRequestsScreenState
    extends State<DoctorUrgentRequestsScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loading = true;

  // UI filter:
  // - open
  // - handled (يشمل handled + rejected + cancelled كـ "غير مفتوح")
  // - all
  String statusFilter = 'open';

  List<UrgentRequestListItemDto> items = const [];

  bool actionLoading = false; // يمنع تعدد العمليات بالتزامن

  @override
  void initState() {
    super.initState();
    fetchUrgentRequests();
  }

  // -------------------- helpers --------------------

  bool _isOpen(UrgentRequestListItemDto it) =>
      it.status.trim().toLowerCase() == 'open';

  String _statusAr(String st) {
    final s = st.trim().toLowerCase();
    switch (s) {
      case 'open':
        return 'مفتوح';
      case 'handled':
        return 'تمت المعالجة';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'ملغى';
      default:
        return st;
    }
  }

  String _handledTypeAr(String? t) {
    final v = (t ?? '').trim().toLowerCase();
    switch (v) {
      case 'scheduled':
        return 'تمت الجدولة';
      case 'rejected':
        return 'تم الرفض';
      case 'cancelled':
        return 'تم الإلغاء';
      case 'handled':
        return 'تمت المعالجة';
      default:
        return 'تمت المعالجة';
    }
  }

  Color _statusColor(BuildContext context, UrgentRequestListItemDto it) {
    final scheme = Theme.of(context).colorScheme;
    final st = it.status.trim().toLowerCase();
    if (st == 'open') return scheme.primary;
    if (st == 'handled') return scheme.secondary;
    if (st == 'rejected') return scheme.error;
    return scheme.outline;
  }

  String _fmtDateTimeLocal(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _triageLine(UrgentRequestListItemDto it) {
    final parts = <String>[];

    final symptoms = (it.symptomsText ?? '').trim();
    if (symptoms.isNotEmpty) parts.add('أعراض: $symptoms');

    final temp = (it.temperatureC ?? '').trim();
    if (temp.isNotEmpty) parts.add('حرارة: $temp');

    if (it.bpSystolic != null && it.bpDiastolic != null) {
      parts.add('ضغط: ${it.bpSystolic}/${it.bpDiastolic}');
    }

    if (it.heartRate != null) parts.add('نبض: ${it.heartRate}');

    if (parts.isEmpty) return 'لا توجد بيانات تقييم حالة.';
    return parts.join(' • ');
  }

  // -------------------- data fetch --------------------

  Future<void> fetchUrgentRequests() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final data = await appointmentsService.fetchMyUrgentRequests(
        status: statusFilter, // open | handled | all
      );

      setState(() {
        items = data;
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
        items = const [];
      });
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'تعذّر تحميل الطلبات العاجلة.');
      setState(() {
        loading = false;
        items = const [];
      });
    }
  }

  // -------------------- actions --------------------

  Future<void> _rejectRequest(UrgentRequestListItemDto it) async {
    // سياسة: يُسمح فقط للطلبات المفتوحة
    if (!_isOpen(it)) {
      showAppSnackBar(
        context,
        'لا يمكن رفض طلب غير مفتوح.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('رفض الطلب العاجل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يمكنك إضافة سبب الرفض (اختياري).'),
              const SizedBox(height: 10),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'سبب الرفض...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد الرفض'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => actionLoading = true);

    try {
      await appointmentsService.rejectUrgentRequest(
        urgentRequestId: it.id,
        reason:
            reasonController.text.trim().isEmpty
                ? null
                : reasonController.text.trim(),
      );

      if (!mounted) return;

      showAppSuccessSnackBar(context, 'تم رفض الطلب.');
      await fetchUrgentRequests();
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
      showAppErrorSnackBar(context, 'تعذّر رفض الطلب.');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  Future<void> _scheduleRequest(UrgentRequestListItemDto it) async {
    // سياسة: يُسمح فقط للطلبات المفتوحة
    if (!_isOpen(it)) {
      showAppSnackBar(
        context,
        'لا يمكن جدولة طلب غير مفتوح.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final now = DateTime.now();
    DateTime selectedDate = now;
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(
      now.add(const Duration(hours: 1)),
    );
    bool allowOverbook = false;
    final notesController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate.isBefore(now) ? now : selectedDate,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setModalState(() {
                selectedDate = picked;
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked == null) return;
              setModalState(() {
                selectedTime = picked;
              });
            }

            final dateText =
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
            final timeText =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('جدولة الطلب العاجل'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('التاريخ'),
                      subtitle: Text(dateText),
                      onTap: pickDate,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text('الوقت'),
                      subtitle: Text(timeText),
                      onTap: pickTime,
                    ),
                    const SizedBox(height: 8),

                    // توضيح عملي: Overbook فقط إذا أردت تجاوز عدم وجود slot.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: allowOverbook,
                      onChanged: (v) => setModalState(() => allowOverbook = v),
                      title: const Text('السماح بـ Overbook'),
                      subtitle: const Text(
                        'فعّله فقط إذا كنت تريد إدخال الموعد حتى لو كان الوقت ممتلئاً.',
                      ),
                    ),

                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'ملاحظة للطبيب/المريض (اختياري)...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأكيد الجدولة'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (ok != true) return;

    final scheduledLocal = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // we send UTC ISO
    final dateTimeIso = scheduledLocal.toUtc().toIso8601String();

    setState(() => actionLoading = true);

    try {
      final res = await appointmentsService.scheduleUrgentRequest(
        urgentRequestId: it.id,
        dateTimeIso: dateTimeIso,
        allowOverbook: allowOverbook,
        notes:
            notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
      );

      if (!mounted) return;

      showAppSuccessSnackBar(
        context,
        'تمت جدولة الطلب. رقم الموعد: ${res.appointment.id}',
      );

      await fetchUrgentRequests();
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
      showAppErrorSnackBar(context, 'تعذّر جدولة الطلب.');
    } finally {
      if (mounted) setState(() => actionLoading = false);
    }
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات العاجلة'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: loading ? null : fetchUrgentRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: statusFilter,
              decoration: const InputDecoration(
                labelText: 'الحالة',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'open', child: Text('مفتوح')),
                DropdownMenuItem(value: 'handled', child: Text('تمت المعالجة')),
                DropdownMenuItem(value: 'all', child: Text('الكل')),
              ],
              onChanged:
                  loading
                      ? null
                      : (v) async {
                        if (v == null) return;
                        setState(() => statusFilter = v);
                        await fetchUrgentRequests();
                      },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (loading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (items.isEmpty) {
                    return const Center(child: Text('لا توجد طلبات عاجلة.'));
                  }

                  return RefreshIndicator(
                    onRefresh: fetchUrgentRequests,
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final it = items[index];

                        final patientName = (it.patientName ?? '').trim();
                        final typeName = (it.appointmentTypeName ?? '').trim();

                        final title =
                            patientName.isNotEmpty
                                ? patientName
                                : 'مريض رقم ${it.patient}';

                        final createdText = _fmtDateTimeLocal(it.createdAt);

                        final scoreText =
                            (it.score != null)
                                ? 'الخطورة: ${it.score}/10'
                                : 'الخطورة: غير متاحة';

                        final confidenceText =
                            (it.confidence != null)
                                ? 'ثقة: ${it.confidence}%'
                                : null;

                        final triageText = _triageLine(it);

                        final handledAtText =
                            (it.handledAt != null)
                                ? _fmtDateTimeLocal(it.handledAt!)
                                : null;

                        final rejectedReason = (it.rejectedReason ?? '').trim();

                        final statusText = _statusAr(it.status);
                        final statusColor = _statusColor(context, it);

                        // NEW: clarify handling type (only for non-open)
                        final handledTypeText =
                            !_isOpen(it)
                                ? _handledTypeAr(it.handledType)
                                : null;

                        final scheduledId = it.scheduledAppointmentId;

                        final details = <String>[
                          'تم الإنشاء: $createdText',
                          scoreText,
                          if (confidenceText != null) confidenceText,
                          'الحالة: $statusText',
                          if (handledTypeText != null)
                            'نوع المعالجة: $handledTypeText',
                          if (handledAtText != null)
                            'تاريخ المعالجة: $handledAtText',
                          if (scheduledId != null) 'رقم الموعد: $scheduledId',
                          if (rejectedReason.isNotEmpty)
                            'سبب الرفض: $rejectedReason',
                        ];

                        final subtitleLines = <String>[
                          if (typeName.isNotEmpty) 'نوع الزيارة: $typeName',
                          triageText,
                          ...details,
                        ];

                        final bool canAct = _isOpen(it);

                        return Card(
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitleLines.join('\n'),
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if ((it.notes ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'ملاحظة: ${(it.notes ?? '').trim()}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],

                                // IMPORTANT:
                                // إذا الطلب غير مفتوح: نخفي الأزرار كلياً لتجنب الالتباس.
                                if (canAct) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              actionLoading
                                                  ? null
                                                  : () => _rejectRequest(it),
                                          icon: const Icon(Icons.block),
                                          label: const Text('رفض'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              actionLoading
                                                  ? null
                                                  : () => _scheduleRequest(it),
                                          icon:
                                              actionLoading
                                                  ? const SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.event_available,
                                                  ),
                                          label: Text(
                                            actionLoading
                                                ? '...جارٍ التنفيذ'
                                                : 'جدولة',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
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
        ),
      ),
    );
  }
}
