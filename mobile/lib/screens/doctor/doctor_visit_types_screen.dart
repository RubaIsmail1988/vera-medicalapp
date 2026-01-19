import 'package:flutter/material.dart';

import '../../models/appointment_type.dart';
import '../../models/doctor_appointment_type.dart';
// NOTE: DoctorSpecificVisitType is intentionally disabled for now (future feature).
// import '../../models/doctor_specific_visit_type.dart';

import '../../services/appointment_type_service.dart';
import '../../services/doctor_appointment_type_service.dart';
// NOTE: DoctorSpecificVisitType is intentionally disabled for now (future feature).
// import '../../services/doctor_specific_visit_type_service.dart';

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

  // NOTE: Disabled for now (future feature).
  // final DoctorSpecificVisitTypeService doctorSpecificService =
  //     DoctorSpecificVisitTypeService();

  bool loading = false;
  String? errorMessage;

  List<AppointmentType> types = [];
  List<DoctorAppointmentType> items = [];

  // NOTE: Disabled for now (future feature).
  // List<DoctorSpecificVisitType> specificItems = [];

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

      // NOTE: Disabled for now (future feature).
      // final resultSpecific = await doctorSpecificService.fetchMine();
      // resultSpecific.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;

      setState(() {
        types = resultTypes;
        items = resultMine;
        // specificItems = resultSpecific;
      });
    } catch (e) {
      if (!mounted) return;

      final msg = "تعذر تحميل إعدادات أنواع الزيارة. حاول مرة أخرى.";
      setState(() => errorMessage = msg);

      showAppSnackBar(context, msg, type: AppSnackBarType.error);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String typeNameById(int id) {
    for (final t in types) {
      if (t.id == id) return t.typeName;
    }
    return "نوع زيارة #$id";
  }

  // ---------------------------------------------------------------------------
  // UI helpers
  // ---------------------------------------------------------------------------

  Widget stateCard({
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

  Widget primaryButton({
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

  Widget sectionHeader(
    String title, {
    String? subtitle,
    IconData icon = Icons.category_outlined,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (subtitle != null && subtitle.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget disabledFeatureCard({required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.construction_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text("قيد التطوير"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs: Central types (existing)
  // ---------------------------------------------------------------------------

  Future<void> openAddCentralDialog() async {
    if (types.isEmpty) {
      showAppSnackBar(
        context,
        "لا توجد أنواع زيارات معرفة من الأدمن.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    int selectedTypeId = types.first.id;
    final durationController = TextEditingController(text: "15");

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("إضافة نوع زيارة (مركزي)"),
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
                  hintText: "مثال: 15",
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
        "تم تحديد المدة مسبقاً",
        type: AppSnackBarType.error,
      );
      setState(() => loading = false);
    }
  }

  Future<void> openEditCentralDialog(DoctorAppointmentType item) async {
    final durationController = TextEditingController(
      text: item.durationMinutes.toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text("تعديل: ${typeNameById(item.appointmentType)}"),
          content: TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "المدة بالدقائق",
              hintText: "مثال: 15",
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

  Future<void> deleteCentralItem(int id) async {
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canAddCentral = !loading && types.isNotEmpty;

    if (loading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (errorMessage != null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text("مدد أنواع الزيارة")),
          body: stateCard(
            icon: Icons.error_outline,
            title: "حدث خطأ",
            message: errorMessage!,
            tone: AppSnackBarType.error,
            action: primaryButton(label: "إعادة المحاولة", onPressed: loadData),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("مدد أنواع الزيارة")),
        body: RefreshIndicator(
          onRefresh: loadData,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              sectionHeader(
                "الأنواع المركزية (Admin)",
                subtitle: "تحدد النوع من قائمة الأدمن ثم تضبط مدته لديك.",
                icon: Icons.list_alt_outlined,
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          const Text(
                            "لم يتم تحديد مدد لأنواع الزيارة المركزية بعد.",
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  canAddCentral ? openAddCentralDialog : null,
                              icon: const Icon(Icons.add),
                              label: const Text("إضافة نوع مركزي"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...items.map((item) {
                  final title = typeNameById(item.appointmentType);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Card(
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
                        onTap: () => openEditCentralDialog(item),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              openEditCentralDialog(item);
                            } else if (value == 'delete') {
                              deleteCentralItem(item.id);
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
                    ),
                  );
                }),

              const SizedBox(height: 6),

              sectionHeader(
                "أنواع خاصة بالطبيب",
                subtitle:
                    "ميزة مستقبلية (غير مفعّلة الآن). سيتم تفعيلها لاحقًا عند اعتماد آلية حجز واضحة لها.",
                icon: Icons.person_pin_outlined,
              ),
              disabledFeatureCard(
                title: "أنواع خاصة بالطبيب (قيد التطوير)",
                message:
                    "حاليًا الحجز يعتمد فقط على الأنواع المركزية (Admin) مع إمكانية تخصيص المدة للطبيب. "
                    "الأنواع الخاصة ستُفعّل لاحقًا عند تثبيت منطق الحجز والربط بشكل رسمي.",
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: canAddCentral ? openAddCentralDialog : null,
          icon: const Icon(Icons.add),
          label: const Text("إضافة نوع مركزي"),
        ),
      ),
    );
  }
}
