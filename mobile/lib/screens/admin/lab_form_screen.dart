import 'package:flutter/material.dart';

import '/models/lab.dart';
import '/models/governorate.dart';
import '/services/lab_service.dart';
import '/services/governorate_service.dart';

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
    final lab = widget.lab;

    nameController = TextEditingController(text: lab?.name ?? "");
    addressController = TextEditingController(text: lab?.address ?? "");
    latitudeController = TextEditingController(
      text: lab?.latitude?.toString() ?? "",
    );
    longitudeController = TextEditingController(
      text: lab?.longitude?.toString() ?? "",
    );
    specialtyController = TextEditingController(text: lab?.specialty ?? "");
    contactInfoController = TextEditingController(text: lab?.contactInfo ?? "");

    selectedGovernorateId = lab?.governorate;

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

        // لو كنا في edit وما في قيمة مطابقة (حالة نادرة) نتركها null
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

    try {
      final isEdit = widget.lab != null;
      final response =
          isEdit
              ? await labService.updateLab(lab)
              : await labService.createLab(lab);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? "تم تحديث المخبر" : "تم إنشاء المخبر"),
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
      ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
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
      appBar: AppBar(title: Text(isEdit ? "تعديل مخبر" : "إضافة مخبر")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "اسم المخبر"),
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
                decoration: const InputDecoration(labelText: "Latitude"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: longitudeController,
                decoration: const InputDecoration(labelText: "Longitude"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: "الاختصاص"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: contactInfoController,
                decoration: const InputDecoration(labelText: "معلومات الاتصال"),
              ),
              const SizedBox(height: 24),

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
