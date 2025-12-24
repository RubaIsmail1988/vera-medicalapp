import 'package:flutter/material.dart';

import '../../models/appointment_type.dart';
import '../../models/doctor_appointment_type.dart';
import '../../services/appointment_type_service.dart';
import '../../services/doctor_appointment_type_service.dart';
import '../../utils/ui_helpers.dart';

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
  String? errorMessage;

  List<AppointmentType> types = [];
  List<DoctorAppointmentType> items = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final resultTypes =
          await appointmentTypeService.fetchAppointmentTypesReadOnly();
      final resultMine = await doctorTypeService.fetchMine();

      if (!mounted) return;

      setState(() {
        types = resultTypes;
        items = resultMine;
      });
    } catch (e) {
      if (!mounted) return;

      final msg = "تعذر تحميل إعدادات أنواع الزيارة. حاول مرة أخرى.";
      setState(() => errorMessage = msg);

      showAppSnackBar(context, msg, type: AppSnackBarType.error);
    } finally {
      // ignore: control_flow_in_finally
      if (!mounted) return;

      setState(() => loading = false);
    }
  }

  String _typeName(int id) {
    for (final t in types) {
      if (t.id == id) return t.typeName;
    }
    return "نوع زيارة #$id";
  }

  // -----------------------------
  // UI helpers
  // -----------------------------

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    required AppSnackBarType tone,
    Widget? action,
  }) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;

    switch (tone) {
      case AppSnackBarType.success:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        break;
      case AppSnackBarType.warning:
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        break;
      case AppSnackBarType.error:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case AppSnackBarType.info:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        break;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: bg,
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData icon = Icons.refresh,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  // -----------------------------
  // Dialogs
  // -----------------------------

  Future<void> openAddDialog() async {
    if (types.isEmpty) {
      showAppSnackBar(
        context,
        "لا توجد أنواع زيارات معرفة من الأدمن.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    int selectedTypeId = types.first.id;
    final durationController = TextEditingController(text: "20");

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("إضافة نوع زيارة"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedTypeId,
                items:
                    types
                        .map(
                          (t) => DropdownMenuItem<int>(
                            value: t.id,
                            child: Text(t.typeName),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  selectedTypeId = v;
                },
                decoration: const InputDecoration(
                  labelText: "نوع الزيارة",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "المدة بالدقائق",
                  hintText: "مثال: 20",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );

    final durationRaw = durationController.text.trim();
    durationController.dispose();

    if (!mounted) return;
    if (ok != true) return;

    final duration = int.tryParse(durationRaw) ?? 0;
    if (duration <= 0) {
      showAppSnackBar(
        context,
        "أدخل مدة صحيحة أكبر من 0.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => loading = true);

    try {
      await doctorTypeService.create(
        appointmentTypeId: selectedTypeId,
        durationMinutes: duration,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        "تمت الإضافة بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        "فشل حفظ الإعدادات. حاول مرة أخرى.",
        type: AppSnackBarType.error,
      );
      setState(() => loading = false);
    }
  }

  Future<void> openEditDialog(DoctorAppointmentType item) async {
    final durationController = TextEditingController(
      text: item.durationMinutes.toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("تعديل: ${_typeName(item.appointmentType)}"),
          content: TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "المدة بالدقائق",
              hintText: "مثال: 20",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );

    final durationRaw = durationController.text.trim();
    durationController.dispose();

    if (!mounted) return;
    if (ok != true) return;

    final duration = int.tryParse(durationRaw) ?? 0;
    if (duration <= 0) {
      showAppSnackBar(
        context,
        "أدخل مدة صحيحة أكبر من 0.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => loading = true);

    try {
      await doctorTypeService.updateDuration(
        id: item.id,
        durationMinutes: duration,
      );

      if (!mounted) return;
      showAppSnackBar(
        context,
        "تم التعديل بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        "فشل تعديل الإعدادات. حاول مرة أخرى.",
        type: AppSnackBarType.error,
      );
      setState(() => loading = false);
    }
  }

  Future<void> deleteItem(int id) async {
    final confirm = await showConfirmDialog(
      context,
      title: "تأكيد الحذف",
      message: "هل أنت متأكد من حذف هذا النوع من زياراتك؟",
      confirmText: "حذف",
      cancelText: "إلغاء",
      danger: true,
    );

    if (!mounted) return;
    if (!confirm) return;

    setState(() => loading = true);

    try {
      await doctorTypeService.delete(id);

      if (!mounted) return;
      showAppSnackBar(
        context,
        "تم الحذف بنجاح.",
        type: AppSnackBarType.success,
      );

      await loadData();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        "فشل حذف الإعداد. حاول مرة أخرى.",
        type: AppSnackBarType.error,
      );
      setState(() => loading = false);
    }
  }

  // -----------------------------
  // Build
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    final canAdd = !loading && types.isNotEmpty;

    Widget body;

    if (loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (errorMessage != null) {
      body = _stateCard(
        icon: Icons.error_outline,
        title: "حدث خطأ",
        message: errorMessage!,
        tone: AppSnackBarType.error,
        action: _primaryButton(label: "إعادة المحاولة", onPressed: loadData),
      );
    } else if (items.isEmpty) {
      body = _stateCard(
        icon: Icons.timer_outlined,
        title: "لا توجد إعدادات بعد",
        message: "لم يتم تحديد مدد لأنواع الزيارة حتى الآن.",
        tone: AppSnackBarType.info,
        action: _primaryButton(
          label: "إضافة نوع زيارة",
          icon: Icons.add,
          onPressed: canAdd ? openAddDialog : null,
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: loadData,
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            final title = _typeName(item.appointmentType);

            return Card(
              elevation: 0,
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.timer_outlined)),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text("المدة: ${item.durationMinutes} دقيقة"),
                onTap: () => openEditDialog(item),
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

    return Scaffold(
      appBar: AppBar(title: const Text("مدد أنواع الزيارة")),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canAdd ? openAddDialog : null,
        icon: const Icon(Icons.add),
        label: const Text("إضافة"),
      ),
    );
  }
}
