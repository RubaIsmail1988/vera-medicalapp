import 'package:flutter/material.dart';

import '../../models/doctor_availability.dart';
import '../../services/doctor_availability_service.dart';
import '/utils/ui_helpers.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() =>
      DoctorAvailabilityScreenState();
}

class DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  final DoctorAvailabilityService service = DoctorAvailabilityService();

  bool loading = false;

  // Fetch errors => inline state (no SnackBar)
  ({String title, String message, IconData icon})? inlineError;

  List<DoctorAvailability> items = [];

  static const List<String> daysEn = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  static const Map<String, String> dayLabelAr = {
    "Monday": "الاثنين",
    "Tuesday": "الثلاثاء",
    "Wednesday": "الأربعاء",
    "Thursday": "الخميس",
    "Friday": "الجمعة",
    "Saturday": "السبت",
    "Sunday": "الأحد",
  };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // -------------------------------
  // Helpers
  // -------------------------------

  bool isDayConfigured(String dayEn) {
    for (final a in items) {
      if (a.dayOfWeek == dayEn) return true;
    }
    return false;
  }

  String labelDay(String dayEn) => dayLabelAr[dayEn] ?? dayEn;

  String formatTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  bool isTimeRangeValid(TimeOfDay start, TimeOfDay end) {
    final startTotal = start.hour * 60 + start.minute;
    final endTotal = end.hour * 60 + end.minute;
    return startTotal < endTotal;
  }

  void setLoading(bool v) {
    if (!mounted) return;
    setState(() => loading = v);
  }

  int _dayIndex(String dayEn) {
    final idx = daysEn.indexOf(dayEn);
    return idx == -1 ? 999 : idx;
  }

  // -------------------------------
  // Data (Fetch)
  // -------------------------------

  Future<void> loadData() async {
    setLoading(true);

    if (mounted) {
      setState(() => inlineError = null);
    }

    try {
      final result = await service.fetchMine();
      if (!mounted) return;

      final sorted = [...result];
      sorted.sort(
        (a, b) => _dayIndex(a.dayOfWeek).compareTo(_dayIndex(b.dayOfWeek)),
      );

      setState(() {
        items = sorted;
        inlineError = null;
      });
    } catch (e) {
      if (!mounted) return;

      //  Fetch error => Inline only (wifi_off) — no SnackBar
      final mapped = mapFetchExceptionToInlineState(e);

      setState(() {
        items = [];
        inlineError = (
          title: mapped.title,
          message: mapped.message,
          icon: mapped.icon,
        );
      });
    } finally {
      setLoading(false);
    }
  }

  // -------------------------------
  // Dialog (Add/Edit)
  // -------------------------------

  Future<AvailabilityDialogResult?> openAvailabilityDialog({
    required bool isEdit,
    DoctorAvailability? item,
  }) async {
    String selectedDay =
        item?.dayOfWeek ??
        daysEn.firstWhere(
          (d) => !isDayConfigured(d),
          orElse: () => daysEn.first,
        );

    TimeOfDay start =
        item != null
            ? parseTime(item.startTime)
            : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay end =
        item != null
            ? parseTime(item.endTime)
            : const TimeOfDay(hour: 12, minute: 0);

    final result = await showDialog<AvailabilityDialogResult>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (innerContext, setInnerState) {
              Future<void> pickStart() async {
                final picked = await showTimePicker(
                  context: innerContext,
                  initialTime: start,
                  builder: (pickerContext, child) {
                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked == null) return;
                setInnerState(() => start = picked);
              }

              Future<void> pickEnd() async {
                final picked = await showTimePicker(
                  context: innerContext,
                  initialTime: end,
                  builder: (pickerContext, child) {
                    return Directionality(
                      textDirection: TextDirection.rtl,
                      child: child ?? const SizedBox.shrink(),
                    );
                  },
                );
                if (picked == null) return;
                setInnerState(() => end = picked);
              }

              return AlertDialog(
                title: Text(isEdit ? "تعديل دوام" : "إضافة دوام"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedDay,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "اليوم",
                        border: OutlineInputBorder(),
                      ),
                      items:
                          daysEn.map((d) {
                            final disabled = !isEdit && isDayConfigured(d);
                            return DropdownMenuItem<String>(
                              value: d,
                              enabled: !disabled,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  disabled
                                      ? "${labelDay(d)} (مضاف)"
                                      : labelDay(d),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setInnerState(() => selectedDay = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: pickStart,
                            child: Text("بداية: ${formatTime(start)}"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: pickEnd,
                            child: Text("نهاية: ${formatTime(end)}"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    if (!isTimeRangeValid(start, end))
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "وقت البداية يجب أن يكون قبل وقت النهاية.",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text("إلغاء"),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!isTimeRangeValid(start, end)) {
                        showAppSnackBar(
                          context,
                          "وقت البداية يجب أن يكون قبل وقت النهاية.",
                          type: AppSnackBarType.warning,
                        );
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                        AvailabilityDialogResult(
                          dayOfWeek: selectedDay,
                          startTime: formatTime(start),
                          endTime: formatTime(end),
                        ),
                      );
                    },
                    child: const Text("حفظ"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    return result;
  }

  // -------------------------------
  // Actions (SnackBar allowed)
  // -------------------------------

  Future<void> addAvailability() async {
    final result = await openAvailabilityDialog(isEdit: false);
    if (result == null) return;

    if (isDayConfigured(result.dayOfWeek)) {
      showAppSnackBar(
        // ignore: use_build_context_synchronously
        context,
        "هذا اليوم مضاف مسبقًا.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    setLoading(true);

    try {
      await service.create(
        dayOfWeek: result.dayOfWeek,
        startTime: result.startTime,
        endTime: result.endTime,
      );
      if (!mounted) return;

      showAppSnackBar(
        context,
        "تمت إضافة الدوام بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: "فشل حفظ الدوام. حاول مرة أخرى.",
      );
    } finally {
      setLoading(false);
    }
  }

  Future<void> editAvailability(DoctorAvailability item) async {
    final result = await openAvailabilityDialog(isEdit: true, item: item);
    if (result == null) return;

    setLoading(true);

    try {
      await service.updateTimes(
        id: item.id,
        startTime: result.startTime,
        endTime: result.endTime,
      );
      if (!mounted) return;

      showAppSnackBar(
        context,
        "تم تحديث الدوام بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: "فشل تحديث الدوام. حاول مرة أخرى.",
      );
    } finally {
      setLoading(false);
    }
  }

  Future<void> deleteAvailability(DoctorAvailability item) async {
    final ok = await showConfirmDialog(
      context,
      title: "تأكيد الحذف",
      message:
          "هل تريد حذف دوام يوم: ${labelDay(item.dayOfWeek)}؟\nهذا الإجراء لا يمكن التراجع عنه.",
      confirmText: "حذف",
      cancelText: "إلغاء",
      danger: true,
    );

    if (!ok) return;

    setLoading(true);

    try {
      await service.delete(item.id);
      if (!mounted) return;

      showAppSnackBar(
        context,
        "تم حذف الدوام بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: "فشل حذف الدوام. حاول مرة أخرى.",
      );
    } finally {
      setLoading(false);
    }
  }

  // -------------------------------
  // UI helper for empty state only
  // -------------------------------

  Widget buildEmptyCard() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(radius: 26, child: Icon(Icons.schedule)),
                const SizedBox(height: 12),
                Text(
                  "لا توجد أوقات دوام",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "لم يتم تحديد أوقات الدوام بعد.\nاضغط على زر (إضافة) لإضافة أول دوام.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------
  // Build
  // -------------------------------

  @override
  Widget build(BuildContext context) {
    final allDaysConfigured = items.length >= daysEn.length;

    Widget body;

    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (inlineError != null) {
      final e = inlineError!;
      body = AppInlineErrorState(
        title: e.title,
        message: e.message,
        icon: e.icon,
        onRetry: loadData,
      );
    } else if (items.isEmpty) {
      body = buildEmptyCard();
    } else {
      body = RefreshIndicator(
        onRefresh: loadData,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];

            return Card(
              elevation: 0,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.schedule)),
                title: Text(
                  labelDay(item.dayOfWeek),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text("${item.startTime} - ${item.endTime}"),
                onTap: () => editAvailability(item),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      editAvailability(item);
                    } else if (value == 'delete') {
                      deleteAvailability(item);
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('تعديل')),
                        PopupMenuItem(value: 'delete', child: Text('حذف')),
                      ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("أوقات دوام الطبيب"),
          actions: [
            IconButton(
              tooltip: "تحديث",
              onPressed: loading ? null : loadData,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: body,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: (loading || allDaysConfigured) ? null : addAvailability,
          icon: const Icon(Icons.add),
          label: const Text("إضافة"),
        ),
      ),
    );
  }
}

class AvailabilityDialogResult {
  final String dayOfWeek; // EN value for backend
  final String startTime; // HH:mm
  final String endTime; // HH:mm

  const AvailabilityDialogResult({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });
}
