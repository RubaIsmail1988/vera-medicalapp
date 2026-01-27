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

  // Fetch errors => inline state (no SnackBar)
  ({String title, String message, IconData icon})? inlineError;

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
      inlineError = null;
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
        inlineError = null;
      });
    } catch (e) {
      if (!mounted) return;

      // ✅ Fetch error => Inline only (wifi_off) — no SnackBar
      final mapped = mapFetchExceptionToInlineState(e);

      setState(() {
        types = [];
        items = [];
        inlineError = (
          title: mapped.title,
          message: mapped.message,
          icon: mapped.icon,
        );
      });
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

  bool isTypeAlreadyAdded(int appointmentTypeId) {
    for (final x in items) {
      if (x.appointmentType == appointmentTypeId) return true;
    }
    return false;
  }

  int defaultDurationByTypeId(int id) {
    for (final t in types) {
      if (t.id == id) return t.defaultDurationMinutes;
    }
    return 15;
  }

  Widget sectionHeader(
    String title, {
    String? subtitle,
    IconData icon = Icons.category_outlined,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.right,
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.construction_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.right),
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

  int pickDefaultTypeId() {
    if (types.isEmpty) return 0;

    // الأفضل: اختر أول نوع غير مُضاف
    for (final t in types) {
      if (!isTypeAlreadyAdded(t.id)) return t.id;
    }

    // إن كانت كلها مضافة، رجّع أول واحد
    return types.first.id;
  }

  Future<void> openAddCentralDialog() async {
    if (types.isEmpty) {
      showAppSnackBar(
        context,
        "لا توجد أنواع زيارات معرفة من الأدمن.",
        type: AppSnackBarType.warning,
      );
      return;
    }

    int selectedTypeId = pickDefaultTypeId();
    final durationController = TextEditingController(
      text: defaultDurationByTypeId(selectedTypeId).toString(),
    );

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text("إضافة نوع زيارة (مركزي)"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedTypeId == 0 ? null : selectedTypeId,
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
                      durationController.text =
                          defaultDurationByTypeId(v).toString();
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
            ),
          );
        },
      );

      if (!mounted) return;
      if (ok != true) return;

      if (selectedTypeId == 0) {
        showAppSnackBar(
          context,
          "يرجى اختيار نوع الزيارة.",
          type: AppSnackBarType.warning,
        );
        return;
      }

      final durationRaw = durationController.text.trim();
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
        showActionErrorSnackBar(
          context,
          exception: e,
          fallback: "فشل الحفظ. حاول مرة أخرى.",
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    } finally {
      durationController.dispose();
    }
  }

  Future<void> openEditCentralDialog(DoctorAppointmentType item) async {
    final durationController = TextEditingController(
      text: item.durationMinutes.toString(),
    );

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
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
            ),
          );
        },
      );

      if (!mounted) return;
      if (ok != true) return;

      final durationRaw = durationController.text.trim();
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
        showActionErrorSnackBar(
          context,
          exception: e,
          fallback: "فشل تعديل الإعدادات. حاول مرة أخرى.",
        );
      } finally {
        if (mounted) setState(() => loading = false);
      }
    } finally {
      durationController.dispose();
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
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: "فشل حذف الإعداد. حاول مرة أخرى.",
      );
      if (mounted) setState(() => loading = false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final canAddCentral = !loading && types.isNotEmpty;

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
    } else {
      body = RefreshIndicator(
        onRefresh: loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            //      sectionHeader(
            //        "الأنواع المركزية (Admin)",
            //        subtitle: "تحدد النوع من قائمة الأدمن ثم تضبط مدته لديك.",
            //       icon: Icons.list_alt_outlined,
            //       trailing: TextButton.icon(
            //         onPressed: canAddCentral ? openAddCentralDialog : null,
            //         icon: const Icon(Icons.add, size: 18),
            //         label: const Text("إضافة"),
            //       ),
            //     ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          "لم يتم تحديد مدد لأنواع الزيارة المركزية بعد.",
                          textAlign: TextAlign.right,
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
                        textAlign: TextAlign.right,
                      ),
                      subtitle: Text(
                        "المدة: ${item.durationMinutes} دقيقة",
                        textAlign: TextAlign.right,
                      ),
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
              //  subtitle: "ميزة مستقبلية سيتم تفعيلها لاحقًا.",
              icon: Icons.person_pin_outlined,
            ),
            disabledFeatureCard(
              title: "أنواع خاصة بالطبيب (قيد التطوير)",
              message:
                  "حاليًا الحجز يعتمد فقط على الأنواع المركزية مع إمكانية تخصيص المدة للطبيب. "
                  "الأنواع الخاصة ستُفعّل لاحقا.",
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("مدد أنواع الزيارة")),
        body: body,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: canAddCentral ? openAddCentralDialog : null,
          icon: const Icon(Icons.add),
          label: const Text("إضافة نوع مركزي"),
        ),
      ),
    );
  }
}
