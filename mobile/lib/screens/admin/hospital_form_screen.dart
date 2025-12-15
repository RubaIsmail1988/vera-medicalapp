import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/services/hospital_service.dart';

class HospitalFormScreen extends StatefulWidget {
  final Hospital? hospital;

  const HospitalFormScreen({super.key, this.hospital});

  @override
  State<HospitalFormScreen> createState() => _HospitalFormScreenState();
}

class _HospitalFormScreenState extends State<HospitalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final HospitalService _hospitalService = HospitalService();

  late TextEditingController _nameController;
  late TextEditingController _governorateController;
  late TextEditingController _addressController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _specialtyController;
  late TextEditingController _contactInfoController;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    final h = widget.hospital;

    _nameController = TextEditingController(text: h?.name ?? "");
    _governorateController = TextEditingController(
      text: h?.governorate.toString() ?? "",
    );
    _addressController = TextEditingController(text: h?.address ?? "");
    _latitudeController = TextEditingController(
      text: h?.latitude?.toString() ?? "",
    );
    _longitudeController = TextEditingController(
      text: h?.longitude?.toString() ?? "",
    );
    _specialtyController = TextEditingController(text: h?.specialty ?? "");
    _contactInfoController = TextEditingController(text: h?.contactInfo ?? "");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _governorateController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _specialtyController.dispose();
    _contactInfoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final int governorateId =
        int.tryParse(_governorateController.text.trim()) ?? 0;
    final double? lat =
        _latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_latitudeController.text.trim());
    final double? lng =
        _longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_longitudeController.text.trim());

    final hospital = Hospital(
      id: widget.hospital?.id,
      name: _nameController.text.trim(),
      governorate: governorateId,
      address:
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
      latitude: lat,
      longitude: lng,
      specialty:
          _specialtyController.text.trim().isEmpty
              ? null
              : _specialtyController.text.trim(),
      contactInfo:
          _contactInfoController.text.trim().isEmpty
              ? null
              : _contactInfoController.text.trim(),
    );

    try {
      final isEdit = widget.hospital != null;
      final response =
          isEdit
              ? await _hospitalService.updateHospital(hospital)
              : await _hospitalService.createHospital(hospital);

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
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم المشفى"),
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _governorateController,
                decoration: const InputDecoration(labelText: "المحافظة (ID)"),
                keyboardType: TextInputType.number,
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: "العنوان"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _latitudeController,
                decoration: const InputDecoration(
                  labelText: "خط العرض (latitude)",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(
                  labelText: "خط الطول (longitude)",
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _specialtyController,
                decoration: const InputDecoration(labelText: "التخصص"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _contactInfoController,
                decoration: const InputDecoration(labelText: "بيانات الاتصال"),
              ),
              const SizedBox(height: 20),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _submit,
                    child: Text(isEdit ? "حفظ التعديلات" : "حفظ"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
