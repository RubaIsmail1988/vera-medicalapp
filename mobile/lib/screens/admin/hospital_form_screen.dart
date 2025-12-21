import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/models/governorate.dart';
import '/services/hospital_service.dart';
import '/services/governorate_service.dart';

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

  late TextEditingController nameController;
  late TextEditingController addressController;
  late TextEditingController latitudeController;
  late TextEditingController longitudeController;
  late TextEditingController specialtyController;
  late TextEditingController contactInfoController;

  bool loading = false;

  List<Governorate> governorates = [];
  int? selectedGovernorateId;
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    final h = widget.hospital;

    nameController = TextEditingController(text: h?.name ?? "");
    addressController = TextEditingController(text: h?.address ?? "");
    latitudeController = TextEditingController(
      text: h?.latitude?.toString() ?? "",
    );
    longitudeController = TextEditingController(
      text: h?.longitude?.toString() ?? "",
    );
    specialtyController = TextEditingController(text: h?.specialty ?? "");
    contactInfoController = TextEditingController(text: h?.contactInfo ?? "");

    selectedGovernorateId = h?.governorate;

    loadGovernorates();
  }

  Future<void> loadGovernorates() async {
    setState(() {
      loadingGovernorates = true;
    });

    try {
      final items = await governorateService.fetchGovernorates();
      if (!mounted) return;

      setState(() {
        governorates = items..sort((a, b) => a.name.compareTo(b.name));
        loadingGovernorates = false;

        // في وضع التعديل: إن لم تعد القيمة موجودة لأي سبب
        if (selectedGovernorateId != null) {
          final exists = governorates.any((g) => g.id == selectedGovernorateId);
          if (!exists) {
            selectedGovernorateId = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingGovernorates = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل تحميل المحافظات: $e")));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("يرجى اختيار المحافظة.")));
      return;
    }

    setState(() => loading = true);

    final double? lat =
        latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(latitudeController.text.trim());
    final double? lng =
        longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(longitudeController.text.trim());

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
      final isEdit = widget.hospital != null;
      final response =
          isEdit
              ? await hospitalService.updateHospital(hospital)
              : await hospitalService.createHospital(hospital);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit ? "تم تحديث المشفى بنجاح" : "تم إنشاء المشفى بنجاح",
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("فشل الحفظ: ${response.body}")));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
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
      appBar: AppBar(title: Text(isEdit ? "تعديل مشفى" : "إضافة مشفى جديد")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "اسم المشفى"),
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 12),

              loadingGovernorates
                  ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  )
                  : DropdownButtonFormField<int>(
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
                    onChanged: (v) {
                      setState(() {
                        selectedGovernorateId = v;
                      });
                    },
                    decoration: const InputDecoration(labelText: "المحافظة"),
                    validator: (v) => v == null ? "الحقل مطلوب" : null,
                  ),

              const SizedBox(height: 12),

              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "العنوان"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: latitudeController,
                decoration: const InputDecoration(
                  labelText: "خط العرض (latitude)",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(
                  labelText: "خط الطول (longitude)",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: "التخصص"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: contactInfoController,
                decoration: const InputDecoration(labelText: "بيانات الاتصال"),
              ),
              const SizedBox(height: 20),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: submit,
                    child: Text(isEdit ? "حفظ التعديلات" : "حفظ"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
