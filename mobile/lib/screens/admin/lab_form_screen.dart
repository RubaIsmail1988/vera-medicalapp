import 'package:flutter/material.dart';

import '/models/lab.dart';
import '/services/lab_service.dart';

class LabFormScreen extends StatefulWidget {
  final Lab? lab;

  const LabFormScreen({super.key, this.lab});

  @override
  State<LabFormScreen> createState() => _LabFormScreenState();
}

class _LabFormScreenState extends State<LabFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final LabService _labService = LabService();

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
    final l = widget.lab;

    _nameController = TextEditingController(text: l?.name ?? "");
    _governorateController = TextEditingController(
      text: l?.governorate.toString() ?? "",
    );
    _addressController = TextEditingController(text: l?.address ?? "");
    _latitudeController = TextEditingController(
      text: l?.latitude?.toString() ?? "",
    );
    _longitudeController = TextEditingController(
      text: l?.longitude?.toString() ?? "",
    );
    _specialtyController = TextEditingController(text: l?.specialty ?? "");
    _contactInfoController = TextEditingController(text: l?.contactInfo ?? "");
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

    final lab = Lab(
      id: widget.lab?.id,
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
      final isEdit = widget.lab != null;
      final response =
          isEdit
              ? await _labService.updateLab(lab)
              : await _labService.createLab(lab);

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
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "اسم المخبر"),
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
                decoration: const InputDecoration(labelText: "Latitude"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _longitudeController,
                decoration: const InputDecoration(labelText: "Longitude"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _specialtyController,
                decoration: const InputDecoration(labelText: "الاختصاص"),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _contactInfoController,
                decoration: const InputDecoration(labelText: "معلومات الاتصال"),
              ),
              const SizedBox(height: 24),

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
