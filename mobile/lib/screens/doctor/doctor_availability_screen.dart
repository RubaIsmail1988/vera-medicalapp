import 'package:flutter/material.dart';

import '../../models/doctor_availability.dart';
import '../../services/doctor_availability_service.dart';

class DoctorAvailabilityScreen extends StatefulWidget {
  const DoctorAvailabilityScreen({super.key});

  @override
  State<DoctorAvailabilityScreen> createState() =>
      DoctorAvailabilityScreenState();
}

class DoctorAvailabilityScreenState extends State<DoctorAvailabilityScreen> {
  final DoctorAvailabilityService service = DoctorAvailabilityService();

  bool loading = false;
  List<DoctorAvailability> items = [];

  static const List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!mounted) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await service.fetchMine();

      if (!mounted) {
        return;
      }

      setState(() {
        items = result;
      });
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  bool isDayConfigured(String day) {
    for (final a in items) {
      if (a.dayOfWeek == day) {
        return true;
      }
    }
    return false;
  }

  String format(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  TimeOfDay parseTime(String value) {
    final parts = value.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  Future<void> openAddDialog() async {
    final messenger = ScaffoldMessenger.of(context); // قبل await

    // اختر أول يوم غير مضاف
    String selectedDay = days.first;
    for (final d in days) {
      if (!isDayConfigured(d)) {
        selectedDay = d;
        break;
      }
    }

    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 12, minute: 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return AlertDialog(
              title: const Text("إضافة دوام"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    items:
                        days.map((d) {
                          final disabled = isDayConfigured(d);
                          return DropdownMenuItem<String>(
                            value: d,
                            enabled: !disabled,
                            child: Text(disabled ? "$d (مضاف)" : d),
                          );
                        }).toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setInnerState(() {
                        selectedDay = v;
                      });
                    },
                    decoration: const InputDecoration(labelText: "اليوم"),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: innerContext,
                              initialTime: start,
                            );
                            if (picked == null) {
                              return;
                            }
                            setInnerState(() {
                              start = picked;
                            });
                          },
                          child: Text("بداية: ${format(start)}"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: innerContext,
                              initialTime: end,
                            );
                            if (picked == null) {
                              return;
                            }
                            setInnerState(() {
                              end = picked;
                            });
                          },
                          child: Text("نهاية: ${format(end)}"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text("حفظ"),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) {
      return;
    }

    final startTotal = start.hour * 60 + start.minute;
    final endTotal = end.hour * 60 + end.minute;
    if (startTotal >= endTotal) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("وقت البداية يجب أن يكون قبل وقت النهاية."),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await service.create(
        dayOfWeek: selectedDay,
        startTime: format(start),
        endTime: format(end),
      );
      await loadData();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> openEditDialog(DoctorAvailability item) async {
    final messenger = ScaffoldMessenger.of(context); // قبل await

    TimeOfDay start = parseTime(item.startTime);
    TimeOfDay end = parseTime(item.endTime);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return AlertDialog(
              title: Text("تعديل دوام: ${item.dayOfWeek}"),
              content: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: innerContext,
                          initialTime: start,
                        );
                        if (picked == null) {
                          return;
                        }
                        setInnerState(() {
                          start = picked;
                        });
                      },
                      child: Text("بداية: ${format(start)}"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: innerContext,
                          initialTime: end,
                        );
                        if (picked == null) {
                          return;
                        }
                        setInnerState(() {
                          end = picked;
                        });
                      },
                      child: Text("نهاية: ${format(end)}"),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text("حفظ"),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) {
      return;
    }

    final startTotal = start.hour * 60 + start.minute;
    final endTotal = end.hour * 60 + end.minute;
    if (startTotal >= endTotal) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("وقت البداية يجب أن يكون قبل وقت النهاية."),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await service.updateTimes(
        id: item.id,
        startTime: format(start),
        endTime: format(end),
      );
      await loadData();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> deleteItem(int id) async {
    final messenger = ScaffoldMessenger.of(context); // قبل await

    if (!mounted) {
      return;
    }
    setState(() {
      loading = true;
    });

    try {
      await service.delete(id);
      await loadData();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.schedule, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "لم يتم تحديد أوقات الدوام بعد.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body =
        loading
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? buildEmptyState()
            : RefreshIndicator(
              onRefresh: loadData,
              child: ListView.separated(
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
                        item.dayOfWeek,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text("${item.startTime} - ${item.endTime}"),
                      onTap: () {
                        openEditDialog(item);
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            openEditDialog(item);
                          } else if (value == 'delete') {
                            deleteItem(item.id);
                          }
                        },
                        itemBuilder:
                            (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('تعديل'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('حذف'),
                              ),
                            ],
                      ),
                    ),
                  );
                },
              ),
            );

    final allDaysConfigured = items.length >= days.length;

    return Scaffold(
      appBar: AppBar(title: const Text("أوقات دوام الطبيب")),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: allDaysConfigured ? null : openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text("إضافة"),
      ),
    );
  }
}
