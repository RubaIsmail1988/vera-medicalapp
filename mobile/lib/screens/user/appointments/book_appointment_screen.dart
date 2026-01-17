import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/appointment_create_request.dart';
import '../../../services/appointments_service.dart';
import '../../../utils/ui_helpers.dart';

class BookAppointmentScreen extends StatefulWidget {
  final int doctorId;
  final String doctorName;
  final String doctorSpecialty;

  const BookAppointmentScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorSpecialty,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loadingTypes = true;
  bool loadingRange = false;
  bool booking = false;

  // payload from /api/appointments/doctors/<id>/visit-types/
  List<Map<String, dynamic>> central = const [];
  List<Map<String, dynamic>> specific = const [];
  bool specificBookingEnabled = false;

  Map<String, dynamic>? selectedCentral;

  // Range UI
  DateTime rangeFromDate = DateTime.now();
  int rangeDays = 7;

  // Range payload (only days with slots)
  List<Map<String, dynamic>> availableDays =
      const []; // [{date, availability, slots}]
  String? selectedDay; // YYYY-MM-DD
  List<String> slots = const [];
  String? selectedSlot;
  Map<String, String>? availability; // {"start":"..","end":".."}
  int resolvedDurationMinutes = 0;

  // Notes
  final TextEditingController notesController = TextEditingController();

  // NEW: Triage (optional)
  final TextEditingController symptomsController = TextEditingController();
  final TextEditingController temperatureController = TextEditingController();
  final TextEditingController bpSysController = TextEditingController();
  final TextEditingController bpDiaController = TextEditingController();
  final TextEditingController heartRateController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();

    symptomsController.dispose();
    temperatureController.dispose();
    bpSysController.dispose();
    bpDiaController.dispose();
    heartRateController.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    loadTypes();
  }

  int _toInt(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _fmtYmd(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _parseYmd(String ymd) {
    final parts = ymd.split('-');
    final y = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 1970;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    final d = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 1;
    return DateTime(y, m, d);
  }

  String _weekdayAr(int weekday) {
    // DateTime.weekday: Mon=1..Sun=7
    switch (weekday) {
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      case 7:
        return 'الأحد';
      default:
        return '';
    }
  }

  String _dayChipLabel(String ymd) {
    final dt = _parseYmd(ymd);
    return '${_weekdayAr(dt.weekday)}  $ymd';
  }

  String _centralLabel(Map<String, dynamic> c) {
    final name = (c['type_name'] ?? '').toString().trim();
    final dur = c['resolved_duration_minutes']?.toString() ?? '';
    final hasOverride = c['has_doctor_override'] == true;

    if (name.isEmpty) return 'نوع غير معروف';
    if (dur.isEmpty) return name;

    return '$name — $dur دقيقة${hasOverride ? " (مخصص)" : ""}';
  }

  /// Builds UTC datetime to send to backend, from:
  /// - selectedDay (YYYY-MM-DD) from range payload
  /// - selectedSlot (HH:MM) from slots list (shown as local time)
  DateTime _buildDateTimeFromSlotYmd(String ymd, String slotHHmm) {
    final date = _parseYmd(ymd);

    final parts = slotHHmm.split(':');
    final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final mi = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    // slot = local time
    return DateTime(date.year, date.month, date.day, hh, mi);
  }

  double? _parseDoubleOrNull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.'));
  }

  int? _parseIntOrNull(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Map<String, dynamic>? _buildTriagePayloadOrNull() {
    final symptoms = symptomsController.text.trim();
    final temp = _parseDoubleOrNull(temperatureController.text);
    final sys = _parseIntOrNull(bpSysController.text);
    final dia = _parseIntOrNull(bpDiaController.text);
    final hr = _parseIntOrNull(heartRateController.text);

    final hasSys = sys != null;
    final hasDia = dia != null;

    // rule: BP must be provided as a pair
    if (hasSys != hasDia) {
      return {
        '__error__':
            'يرجى إدخال الضغط الانقباضي والانبساطي معاً أو تركهما فارغين.',
      };
    }

    final payload = <String, dynamic>{};

    if (symptoms.isNotEmpty) payload['symptoms_text'] = symptoms;
    if (temp != null) payload['temperature_c'] = temp;

    if (sys != null && dia != null) {
      payload['bp_systolic'] = sys;
      payload['bp_diastolic'] = dia;
    }

    if (hr != null) payload['heart_rate'] = hr;

    return payload.isEmpty ? null : payload;
  }

  Future<void> loadTypes() async {
    if (!mounted) return;

    setState(() {
      loadingTypes = true;

      central = const [];
      specific = const [];
      selectedCentral = null;

      loadingRange = false;
      availableDays = const [];
      selectedDay = null;
      slots = const [];
      selectedSlot = null;
      availability = null;
      resolvedDurationMinutes = 0;
    });

    try {
      final payload = await appointmentsService.fetchDoctorVisitTypes(
        doctorId: widget.doctorId,
      );

      if (!mounted) return;

      final enabled = payload['specific_booking_enabled'] == true;

      final centralRaw =
          (payload['central'] is List)
              ? (payload['central'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

      final specificRaw =
          (payload['specific'] is List)
              ? (payload['specific'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

      centralRaw.sort((a, b) {
        final an = (a['type_name'] ?? '').toString();
        final bn = (b['type_name'] ?? '').toString();
        return an.compareTo(bn);
      });

      specificRaw.sort((a, b) {
        final an = (a['name'] ?? '').toString();
        final bn = (b['name'] ?? '').toString();
        return an.compareTo(bn);
      });

      final firstCentral = centralRaw.isNotEmpty ? centralRaw.first : null;

      setState(() {
        central = centralRaw;

        specificBookingEnabled = enabled;
        specific = enabled ? specificRaw : <Map<String, dynamic>>[];

        selectedCentral = firstCentral;
        loadingTypes = false;
      });

      await loadSlotsRange();
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
        loadingTypes = false;
      });
    } catch (_) {
      if (!mounted) return;

      showAppErrorSnackBar(context, 'تعذّر تحميل أنواع الزيارات.');
      setState(() => loadingTypes = false);
    }
  }

  Future<void> pickRangeFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: rangeFromDate.isBefore(now) ? now : rangeFromDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted) return;
    if (picked == null) return;

    setState(() {
      rangeFromDate = picked;
      selectedDay = null;
      selectedSlot = null;
      slots = const [];
      availability = null;
    });

    await loadSlotsRange();
  }

  Future<void> setNextWeekPreset() async {
    final now = DateTime.now();
    if (!mounted) return;

    setState(() {
      rangeFromDate = now;
      rangeDays = 7;

      selectedDay = null;
      selectedSlot = null;
      slots = const [];
      availability = null;
    });

    await loadSlotsRange();
  }

  Future<void> loadSlotsRange() async {
    if (!mounted) return;

    final selected = selectedCentral;
    if (selected == null) {
      setState(() {
        availableDays = const [];
        selectedDay = null;
        slots = const [];
        selectedSlot = null;
        availability = null;
        resolvedDurationMinutes = 0;
      });
      return;
    }

    final appointmentTypeId = _toInt(selected['appointment_type_id']);
    if (appointmentTypeId == 0) {
      setState(() {
        availableDays = const [];
        selectedDay = null;
        slots = const [];
        selectedSlot = null;
        availability = null;
        resolvedDurationMinutes = 0;
      });
      return;
    }

    final fromYmd = _fmtYmd(rangeFromDate);
    final toYmd = _fmtYmd(rangeFromDate.add(Duration(days: rangeDays - 1)));

    setState(() {
      loadingRange = true;

      availableDays = const [];
      selectedDay = null;
      slots = const [];
      selectedSlot = null;
      availability = null;

      resolvedDurationMinutes = _toInt(selected['resolved_duration_minutes']);
    });

    try {
      final payload = await appointmentsService.fetchDoctorSlotsRange(
        doctorId: widget.doctorId,
        appointmentTypeId: appointmentTypeId,
        fromDate: fromYmd,
        toDate: toYmd,
      );

      if (!mounted) return;

      final dur = payload['duration_minutes'];
      final resolved = (dur is num) ? dur.toInt() : int.tryParse('$dur') ?? 0;

      final daysRaw =
          (payload['days'] is List)
              ? (payload['days'] as List)
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
              : <Map<String, dynamic>>[];

      final daysWithSlots =
          daysRaw.where((d) {
            final s = d['slots'];
            return (s is List) && s.isNotEmpty;
          }).toList();

      String? firstDay;
      if (daysWithSlots.isNotEmpty) {
        final d = (daysWithSlots.first['date'] ?? '').toString().trim();
        if (d.isNotEmpty) firstDay = d;
      }

      List<String> initialSlots = const [];
      Map<String, String>? initialAvailability;

      if (firstDay != null) {
        final dayObj = daysWithSlots.firstWhere(
          (x) => (x['date'] ?? '').toString() == firstDay,
          orElse: () => <String, dynamic>{},
        );

        final slotsList =
            (dayObj['slots'] is List)
                ? (dayObj['slots'] as List).map((e) => e.toString()).toList()
                : <String>[];

        final availabilityRaw = dayObj['availability'];
        if (availabilityRaw is Map) {
          final start = (availabilityRaw['start'] ?? '').toString();
          final end = (availabilityRaw['end'] ?? '').toString();
          if (start.trim().isNotEmpty && end.trim().isNotEmpty) {
            initialAvailability = {'start': start, 'end': end};
          }
        }

        initialSlots = slotsList;
      }

      setState(() {
        availableDays = daysWithSlots;
        resolvedDurationMinutes = resolved;

        selectedDay = firstDay;
        slots = initialSlots;
        availability = initialAvailability;
        selectedSlot = slots.isNotEmpty ? slots.first : null;

        loadingRange = false;
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
      setState(() => loadingRange = false);
    } catch (_) {
      if (!mounted) return;

      showAppErrorSnackBar(context, 'تعذّر تحميل الأوقات المتاحة ضمن النطاق.');
      setState(() => loadingRange = false);
    }
  }

  void _selectDay(String ymd) {
    if (!mounted) return;

    final dayObj = availableDays.firstWhere(
      (d) => (d['date'] ?? '').toString() == ymd,
      orElse: () => <String, dynamic>{},
    );

    final slotsList =
        (dayObj['slots'] is List)
            ? (dayObj['slots'] as List).map((e) => e.toString()).toList()
            : <String>[];

    final availabilityRaw = dayObj['availability'];
    Map<String, String>? availabilityMap;
    if (availabilityRaw is Map) {
      final start = (availabilityRaw['start'] ?? '').toString();
      final end = (availabilityRaw['end'] ?? '').toString();
      if (start.trim().isNotEmpty && end.trim().isNotEmpty) {
        availabilityMap = {'start': start, 'end': end};
      }
    }

    setState(() {
      selectedDay = ymd;
      slots = slotsList;
      availability = availabilityMap;
      selectedSlot = slots.isNotEmpty ? slots.first : null;
    });
  }

  Future<void> submitBooking() async {
    final selected = selectedCentral;
    if (selected == null) {
      showAppSnackBar(
        context,
        'اختر نوع الزيارة أولاً.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final appointmentTypeId = _toInt(selected['appointment_type_id']);
    if (appointmentTypeId == 0) {
      showAppErrorSnackBar(context, 'نوع الزيارة غير صالح.');
      return;
    }

    if (selectedDay == null || selectedDay!.trim().isEmpty) {
      showAppSnackBar(
        context,
        'اختر يومًا متاحًا أولاً.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (selectedSlot == null || selectedSlot!.trim().isEmpty) {
      showAppSnackBar(
        context,
        'اختر وقتًا متاحًا أولاً.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final triagePayload = _buildTriagePayloadOrNull();
    if (triagePayload != null && triagePayload.containsKey('__error__')) {
      showAppSnackBar(
        context,
        triagePayload['__error__'].toString(),
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (!mounted) return;
    setState(() => booking = true);

    try {
      final dt = _buildDateTimeFromSlotYmd(selectedDay!, selectedSlot!);

      final req = AppointmentCreateRequest(
        doctorId: widget.doctorId,
        appointmentTypeId: appointmentTypeId,
        dateTime: dt,
        notes: notesController.text.trim(),
        triage: triagePayload, // NEW
      );

      final appointment = await appointmentsService.createAppointment(
        request: req,
      );

      if (!mounted) return;

      showAppSuccessSnackBar(
        context,
        'تم حجز الموعد بنجاح (الحالة: ${appointment.status}).',
      );

      if (!mounted) return;
      context.go('/app/appointments');
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
      showAppErrorSnackBar(context, 'حدث خطأ غير متوقع. حاول مرة أخرى لاحقًا.');
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final availabilityText =
        availability == null
            ? null
            : 'دوام الطبيب: من ${availability!['start']} إلى ${availability!['end']}';

    final daysTitle =
        rangeDays == 7 ? 'الأيام المتاحة (7 أيام)' : 'الأيام المتاحة';

    final bool hasTypesLoaded = !loadingTypes;
    final bool hasCentralSelected = selectedCentral != null;

    return Scaffold(
      appBar: AppBar(title: const Text('حجز موعد')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Card(
              elevation: 0,
              child: ListTile(
                title: Text(widget.doctorName),
                subtitle: Text(widget.doctorSpecialty),
                leading: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),

            Text('نوع الزيارة', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (loadingTypes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (central.isEmpty)
              const Text('لا توجد أنواع زيارات متاحة حالياً لهذا الطبيب.')
            else
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedCentral,
                items:
                    central
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(_centralLabel(c)),
                          ),
                        )
                        .toList(),
                onChanged:
                    booking
                        ? null
                        : (v) async {
                          if (!mounted) return;

                          setState(() {
                            selectedCentral = v;

                            selectedDay = null;
                            selectedSlot = null;
                            slots = const [];
                            availability = null;
                          });

                          await loadSlotsRange();
                        },
                decoration: const InputDecoration(
                  hintText: 'اختر نوع الزيارة',
                  border: OutlineInputBorder(),
                ),
              ),

            if (hasTypesLoaded &&
                specificBookingEnabled &&
                specific.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('أنواع خاصة بالطبيب', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...specific.map((s) {
                final name = (s['name'] ?? '').toString().trim();
                final dur = s['duration_minutes']?.toString() ?? '';
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.star_border),
                    title: Text(name.isEmpty ? 'نوع خاص' : name),
                    subtitle: Text(dur.isEmpty ? '' : 'المدة: $dur دقيقة'),
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Text('نطاق البحث عن الأوقات', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: booking ? null : pickRangeFromDate,
                  icon: const Icon(Icons.date_range),
                  label: Text('بداية النطاق: ${_fmtYmd(rangeFromDate)}'),
                ),
                ChoiceChip(
                  label: const Text('الأسبوع القادم'),
                  selected: rangeDays == 7,
                  onSelected: booking ? null : (_) => setNextWeekPreset(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(daysTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (loadingRange)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (!hasCentralSelected)
              const Text('اختر نوع الزيارة أولاً.')
            else if (availableDays.isEmpty)
              const Text('لا توجد أوقات متاحة ضمن هذا النطاق.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    availableDays.map((d) {
                      final ymd = (d['date'] ?? '').toString().trim();
                      final isSelected = ymd == selectedDay;
                      return ChoiceChip(
                        label: Text(_dayChipLabel(ymd)),
                        selected: isSelected,
                        onSelected: booking ? null : (_) => _selectDay(ymd),
                      );
                    }).toList(),
              ),

            if (availabilityText != null) ...[
              const SizedBox(height: 8),
              Text(availabilityText, style: theme.textTheme.bodySmall),
            ],

            const SizedBox(height: 16),
            Text('الأوقات المتاحة', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (loadingRange)
              const SizedBox.shrink()
            else if (selectedDay == null)
              const Text('اختر يومًا متاحًا أولاً.')
            else if (slots.isEmpty)
              const Text('لا توجد أوقات متاحة في هذا اليوم.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    slots.map((s) {
                      final isSelected = s == selectedSlot;
                      return ChoiceChip(
                        label: Text(s),
                        selected: isSelected,
                        onSelected:
                            booking
                                ? null
                                : (val) {
                                  if (!mounted) return;
                                  setState(() => selectedSlot = val ? s : null);
                                },
                      );
                    }).toList(),
              ),

            // -----------------------------
            // NEW: Triage (optional)
            // -----------------------------
            const SizedBox(height: 16),
            Text('تقييم الحالة (اختياري)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            TextField(
              controller: symptomsController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب الأعراض بإيجاز...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: temperatureController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'الحرارة (°C)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: heartRateController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'النبض (bpm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: bpSysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'الضغط الانقباضي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: bpDiaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'الضغط الانبساطي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),
            Text(
              'ملاحظة: إدخال هذه المعلومات اختياري، ويساعد الطبيب على تقدير أولوية الحالة.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 16),
            Text('ملاحظات (اختياري)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظة للطبيب إن لزم...',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: booking ? null : submitBooking,
                child:
                    booking
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          resolvedDurationMinutes > 0
                              ? 'تأكيد الحجز ($resolvedDurationMinutes دقيقة)'
                              : 'تأكيد الحجز',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
