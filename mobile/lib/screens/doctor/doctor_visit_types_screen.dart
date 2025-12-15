import 'package:flutter/material.dart';

import '../../models/appointment_type.dart';
import '../../models/doctor_appointment_type.dart';
import '../../services/appointment_type_service.dart';
import '../../services/doctor_appointment_type_service.dart';

class DoctorVisitTypesScreen extends StatefulWidget {
  const DoctorVisitTypesScreen({super.key});

  @override
  State<DoctorVisitTypesScreen> createState() => DoctorVisitTypesScreenState();
}

class DoctorVisitTypesScreenState extends State<DoctorVisitTypesScreen> {
  final AppointmentTypeService appointmentTypeService =
      AppointmentTypeService();
  final DoctorAppointmentTypeService doctorTypeService =
      DoctorAppointmentTypeService();

  bool loading = false;
  List<AppointmentType> types = [];
  List<DoctorAppointmentType> items = [];

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
      final resultTypes =
          await appointmentTypeService.fetchAppointmentTypesReadOnly();
      final resultMine = await doctorTypeService.fetchMine();

      if (!mounted) {
        return;
      }

      setState(() {
        types = resultTypes;
        items = resultMine;
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

  String typeName(int id) {
    for (final t in types) {
      if (t.id == id) {
        return t.typeName;
      }
    }
    return "Type #$id";
  }

  Future<void> openAddDialog() async {
    if (types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا توجد أنواع زيارات معرفة من الأدمن.")),
      );
      return;
    }

    int selectedTypeId = types.first.id;
    final durationController = TextEditingController(text: "20");
    final messenger = ScaffoldMessenger.of(context); // قبل await

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("إضافة نوع زيارة للطبيب"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedTypeId,
                items:
                    types
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.typeName),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v == null) {
                    return;
                  }
                  selectedTypeId = v;
                },
                decoration: const InputDecoration(labelText: "نوع الزيارة"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "المدة بالدقائق",
                  hintText: "مثال: 20",
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

    if (ok != true) {
      return;
    }

    final duration = int.tryParse(durationController.text.trim()) ?? 0;
    if (duration <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("أدخل مدة صحيحة أكبر من 0")),
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
      await doctorTypeService.create(
        appointmentTypeId: selectedTypeId,
        durationMinutes: duration,
      );

      if (!mounted) {
        return;
      }

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

  Future<void> openEditDialog(DoctorAppointmentType item) async {
    final messenger = ScaffoldMessenger.of(context); // قبل await
    final durationController = TextEditingController(
      text: item.durationMinutes.toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("تعديل: ${typeName(item.appointmentType)}"),
          content: TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "المدة بالدقائق",
              hintText: "مثال: 20",
            ),
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

    if (ok != true) {
      return;
    }

    final duration = int.tryParse(durationController.text.trim()) ?? 0;
    if (duration <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text("أدخل مدة صحيحة أكبر من 0")),
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
      await doctorTypeService.updateDuration(
        id: item.id,
        durationMinutes: duration,
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
      await doctorTypeService.delete(id);
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
            Icon(Icons.timer_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "لم يتم تحديد مدد لأنواع الزيارة بعد.",
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
                  final title = typeName(item.appointmentType);

                  return Card(
                    elevation: 0,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.timer_outlined),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text("المدة: ${item.durationMinutes} دقيقة"),
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

    return Scaffold(
      appBar: AppBar(title: const Text("مدد أنواع الزيارة")),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text("إضافة"),
      ),
    );
  }
}
