import 'package:flutter/material.dart';

import '/models/governorate.dart';
import '/models/hospital.dart';
import '/services/governorate_service.dart';
import '/services/hospital_service.dart';
import '/utils/ui_helpers.dart';

class HospitalFormScreen extends StatefulWidget {
  final Hospital? hospital;

  const HospitalFormScreen({super.key, this.hospital});

  @override
  State<HospitalFormScreen> createState() => _HospitalFormScreenState();
}

class _HospitalFormScreenState extends State<HospitalFormScreen> {
  final formKey = GlobalKey<FormState>();
  final hospitalService = HospitalService();
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

    final h = widget.hospital;

    nameController = TextEditingController(text: h?.name ?? '');
    addressController = TextEditingController(text: h?.address ?? '');
    latitudeController = TextEditingController(
      text: h?.latitude?.toString() ?? '',
    );
    longitudeController = TextEditingController(
      text: h?.longitude?.toString() ?? '',
    );
    specialtyController = TextEditingController(text: h?.specialty ?? '');
    contactInfoController = TextEditingController(text: h?.contactInfo ?? '');

    selectedGovernorateId = h?.governorate;

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

        if (selectedGovernorateId != null) {
          final exists = governorates.any((g) => g.id == selectedGovernorateId);
          if (!exists) selectedGovernorateId = null;
        }

        // في حالة الإضافة: اختار أول محافظة تلقائياإن لم يكن هناك اختيار
        if (widget.hospital == null &&
            selectedGovernorateId == null &&
            governorates.isNotEmpty) {
          selectedGovernorateId = governorates.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingGovernorates = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل تحميل المحافظات.',
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
    if (loading) return;
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

    final String latRaw = latitudeController.text.trim();
    final String lngRaw = longitudeController.text.trim();

    final double? lat = latRaw.isEmpty ? null : double.tryParse(latRaw);
    final double? lng = lngRaw.isEmpty ? null : double.tryParse(lngRaw);

    final hospital = Hospital(
      id: widget.hospital?.id,
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

    try {
      final bool isEdit = widget.hospital != null;

      if (isEdit) {
        await hospitalService.updateHospital(hospital);
      } else {
        await hospitalService.createHospital(hospital);
      }

      if (!mounted) return;

      showAppSnackBar(
        context,
        isEdit ? 'تم تحديث المشفى بنجاح.' : 'تم إنشاء المشفى بنجاح.',
        type: AppSnackBarType.success,
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل حفظ بيانات المشفى.',
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.hospital != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل مشفى' : 'إضافة مشفى جديد')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المشفى'),
                enabled: !loading,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
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
                  onChanged:
                      loading
                          ? null
                          : (v) => setState(() => selectedGovernorateId = v),
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                  validator: (v) => v == null ? 'الحقل مطلوب' : null,
                ),

              const SizedBox(height: 12),

              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
                enabled: !loading,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: latitudeController,
                decoration: const InputDecoration(
                  labelText: 'خط العرض (latitude)',
                ),
                enabled: !loading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(
                  labelText: 'خط الطول (longitude)',
                ),
                enabled: !loading,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: 'التخصص'),
                enabled: !loading,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: contactInfoController,
                decoration: const InputDecoration(labelText: 'بيانات الاتصال'),
                enabled: !loading,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submit,
                  child:
                      loading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
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
