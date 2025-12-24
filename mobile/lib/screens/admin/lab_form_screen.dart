import 'package:flutter/material.dart';

import '/models/governorate.dart';
import '/models/lab.dart';
import '/services/governorate_service.dart';
import '/services/lab_service.dart';
import '/utils/ui_helpers.dart';

class LabFormScreen extends StatefulWidget {
  final Lab? lab;

  const LabFormScreen({super.key, this.lab});

  @override
  State<LabFormScreen> createState() => _LabFormScreenState();
}

class _LabFormScreenState extends State<LabFormScreen> {
  final formKey = GlobalKey<FormState>();
  final labService = LabService();
  final governorateService = GovernorateService();

  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController latitudeController;
  late final TextEditingController longitudeController;
  late final TextEditingController specialtyController;
  late final TextEditingController contactInfoController;

  bool loading = false;

  List<Governorate> governorates = [];
  int? selectedGovernorateId;
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    final lab = widget.lab;

    nameController = TextEditingController(text: lab?.name ?? '');
    addressController = TextEditingController(text: lab?.address ?? '');
    latitudeController = TextEditingController(
      text: lab?.latitude?.toString() ?? '',
    );
    longitudeController = TextEditingController(
      text: lab?.longitude?.toString() ?? '',
    );
    specialtyController = TextEditingController(text: lab?.specialty ?? '');
    contactInfoController = TextEditingController(text: lab?.contactInfo ?? '');

    selectedGovernorateId = lab?.governorate;

    loadGovernorates();
  }

  Future<void> loadGovernorates() async {
    if (!mounted) return;
    setState(() => loadingGovernorates = true);

    try {
      final items = await governorateService.fetchGovernorates();
      if (!mounted) return;

      items.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        governorates = items;
        loadingGovernorates = false;

        // في وضع التعديل: إن لم تعد القيمة موجودة لأي سبب
        if (selectedGovernorateId != null) {
          final exists = governorates.any((g) => g.id == selectedGovernorateId);
          if (!exists) {
            selectedGovernorateId = null;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingGovernorates = false);

      showAppSnackBar(
        context,
        'فشل تحميل المحافظات.',
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    specialtyController.dispose();
    contactInfoController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedGovernorateId == null) {
      showAppSnackBar(
        context,
        'يرجى اختيار المحافظة.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => loading = true);

    try {
      final latText = latitudeController.text.trim();
      final lngText = longitudeController.text.trim();

      final double? lat = latText.isEmpty ? null : double.tryParse(latText);
      final double? lng = lngText.isEmpty ? null : double.tryParse(lngText);

      final lab = Lab(
        id: widget.lab?.id,
        name: nameController.text.trim(),
        governorate: selectedGovernorateId!,
        address:
            addressController.text.trim().isEmpty
                ? null
                : addressController.text.trim(),
        latitude: lat,
        longitude: lng,
        specialty:
            specialtyController.text.trim().isEmpty
                ? null
                : specialtyController.text.trim(),
        contactInfo:
            contactInfoController.text.trim().isEmpty
                ? null
                : contactInfoController.text.trim(),
      );

      final isEdit = widget.lab != null;

      final response =
          isEdit
              ? await labService.updateLab(lab)
              : await labService.createLab(lab);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        showAppSnackBar(
          context,
          isEdit ? 'تم تحديث المخبر بنجاح.' : 'تم إنشاء المخبر بنجاح.',
          type: AppSnackBarType.success,
        );
        Navigator.pop(context, true);
        return;
      }

      final msg = labService.extractErrorMessage(response);
      showAppSnackBar(context, 'فشل الحفظ: $msg', type: AppSnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'حدث خطأ أثناء الحفظ.',
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.lab != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل مخبر' : 'إضافة مخبر')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المخبر'),
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 12),

              if (loadingGovernorates)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else
                DropdownButtonFormField<int>(
                  value: selectedGovernorateId,
                  items:
                      governorates
                          .map(
                            (g) => DropdownMenuItem<int>(
                              value: g.id,
                              child: Text(g.name),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => selectedGovernorateId = v),
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                  validator: (v) => v == null ? 'الحقل مطلوب' : null,
                ),

              const SizedBox(height: 12),

              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: latitudeController,
                decoration: const InputDecoration(
                  labelText: 'خط العرض (Latitude)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(
                  labelText: 'خط الطول (Longitude)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: 'الاختصاص'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: contactInfoController,
                decoration: const InputDecoration(labelText: 'معلومات الاتصال'),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child:
                      loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
