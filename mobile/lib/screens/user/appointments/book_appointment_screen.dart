import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/appointment_create_request.dart';
import '../../../services/appointments_service.dart';
import '../../../utils/ui_helpers.dart';
import 'package:go_router/go_router.dart';

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
  bool loadingSlots = false;
  bool booking = false;

  // payload from /api/appointments/doctors/<id>/visit-types/
  List<Map<String, dynamic>> central = const [];
  List<Map<String, dynamic>> specific = const [];

  bool specificBookingEnabled = false;

  Map<String, dynamic>? selectedCentral;

  DateTime selectedDate = DateTime.now();

  // slots payload
  List<String> slots = const [];
  String? selectedSlot;
  Map<String, String>? availability; // {"start": "09:00", "end": "12:00"}
  int resolvedDurationMinutes = 0;

  final TextEditingController notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
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

  String _centralLabel(Map<String, dynamic> c) {
    final name = (c['type_name'] ?? '').toString().trim();
    final dur = c['resolved_duration_minutes']?.toString() ?? '';
    final hasOverride = c['has_doctor_override'] == true;

    if (name.isEmpty) return 'نوع غير معروف';
    if (dur.isEmpty) return name;

    return '$name — $dur دقيقة${hasOverride ? " (مخصص)" : ""}';
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  DateTime _buildDateTimeFromSlot(DateTime date, String slotHHmm) {
    final parts = slotHHmm.split(':');
    final hh = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final mi = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;

    return DateTime.utc(date.year, date.month, date.day, hh, mi);
  }

  Future<void> loadTypes() async {
    if (!mounted) return;
    setState(() {
      loadingTypes = true;
      // reset
      central = const [];
      specific = const [];
      selectedCentral = null;
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

        // Contract: booking central only for now
        specificBookingEnabled = enabled;
        specific = enabled ? specificRaw : <Map<String, dynamic>>[];

        selectedCentral = firstCentral;
        loadingTypes = false;
      });

      // Load slots after selecting initial central type
      await loadSlots();
    } on ApiException catch (e) {
      if (!mounted) return;
      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }
      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);
      setState(() => loadingTypes = false);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'تعذّر تحميل أنواع الزيارات.');
      setState(() => loadingTypes = false);
    }
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(now) ? now : selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (!mounted) return;
    if (date == null) return;

    setState(() {
      selectedDate = date;
      selectedSlot = null;
    });

    await loadSlots();
  }

  Future<void> loadSlots() async {
    if (!mounted) return;

    final selected = selectedCentral;
    if (selected == null) {
      setState(() {
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
        slots = const [];
        selectedSlot = null;
        availability = null;
        resolvedDurationMinutes = 0;
      });
      return;
    }

    setState(() {
      loadingSlots = true;
      slots = const [];
      selectedSlot = null;
      availability = null;
      resolvedDurationMinutes = _toInt(selected['resolved_duration_minutes']);
    });

    try {
      final payload = await appointmentsService.fetchDoctorSlots(
        doctorId: widget.doctorId,
        date: _fmtDate(selectedDate),
        appointmentTypeId: appointmentTypeId,
      );

      if (!mounted) return;

      final slotsRaw =
          (payload['slots'] is List)
              ? (payload['slots'] as List).map((e) => e.toString()).toList()
              : <String>[];

      final availabilityRaw = payload['availability'];
      Map<String, String>? availabilityMap;
      if (availabilityRaw is Map) {
        final start = (availabilityRaw['start'] ?? '').toString();
        final end = (availabilityRaw['end'] ?? '').toString();
        if (start.trim().isNotEmpty && end.trim().isNotEmpty) {
          availabilityMap = {'start': start, 'end': end};
        }
      }

      setState(() {
        slots = slotsRaw;
        availability = availabilityMap;
        loadingSlots = false;

        // اختيار افتراضي أول Slot إذا موجود
        selectedSlot = slots.isNotEmpty ? slots.first : null;
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
      setState(() => loadingSlots = false);
    } catch (_) {
      if (!mounted) return;
      showAppErrorSnackBar(context, 'تعذّر تحميل الأوقات المتاحة.');
      setState(() => loadingSlots = false);
    }
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

    if (selectedSlot == null || selectedSlot!.trim().isEmpty) {
      showAppSnackBar(
        context,
        'اختر وقتًا متاحًا أولاً.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => booking = true);

    try {
      final dt = _buildDateTimeFromSlot(selectedDate, selectedSlot!);

      final req = AppointmentCreateRequest(
        doctorId: widget.doctorId,
        appointmentTypeId: appointmentTypeId,
        dateTime: dt,
        notes: notesController.text.trim(),
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

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الحجز')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Card(
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
                            selectedSlot = null;
                          });
                          await loadSlots();
                        },
                decoration: const InputDecoration(hintText: 'اختر نوع الزيارة'),
              ),

            // Contract: hide this section unless enabled
            if (!loadingTypes &&
                specificBookingEnabled &&
                specific.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('أنواع خاصة بالطبيب', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              ...specific.map((s) {
                final name = (s['name'] ?? '').toString();
                final dur = s['duration_minutes']?.toString() ?? '';
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(Icons.star_border),
                    title: Text(name),
                    subtitle: Text(dur.isEmpty ? '' : 'المدة: $dur دقيقة'),
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Text('التاريخ', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: booking ? null : pickDate,
              icon: const Icon(Icons.date_range),
              label: Text(_fmtDate(selectedDate)),
            ),

            if (availabilityText != null) ...[
              const SizedBox(height: 8),
              Text(availabilityText, style: theme.textTheme.bodySmall),
            ],

            const SizedBox(height: 16),
            Text('الأوقات المتاحة', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),

            if (loadingSlots)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (selectedCentral == null)
              const Text('اختر نوع الزيارة أولاً.')
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

            const SizedBox(height: 16),
            Text('ملاحظات (اختياري)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظة للطبيب إن لزم...',
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
