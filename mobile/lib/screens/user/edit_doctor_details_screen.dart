import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/doctor_details.dart';

class EditDoctorDetailsScreen extends StatefulWidget {
  final String
  token; // لن نستخدمه مباشرة لأن DetailsService يستعمل التوكن المخزن
  final int userId;

  final String specialty;
  final int experienceYears;
  final String? notes;

  const EditDoctorDetailsScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.specialty,
    required this.experienceYears,
    this.notes,
  });

  @override
  State<EditDoctorDetailsScreen> createState() =>
      _EditDoctorDetailsScreenState();
}

class _EditDoctorDetailsScreenState extends State<EditDoctorDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _specialtyController;
  late TextEditingController _experienceController;
  late TextEditingController _notesController;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    _specialtyController = TextEditingController(text: widget.specialty);
    _experienceController = TextEditingController(
      text: widget.experienceYears.toString(),
    );
    _notesController = TextEditingController(text: widget.notes ?? "");
  }

  @override
  void dispose() {
    _specialtyController.dispose();
    _experienceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final int expYears = int.tryParse(_experienceController.text.trim()) ?? 0;

    final request = DoctorDetailsRequest(
      userId: widget.userId,
      specialty: _specialtyController.text.trim(),
      experienceYears: expYears,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
    );

    final response = await DetailsService().updateDoctorDetails(request);

    setState(() => loading = false);

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحديث بيانات الطبيب بنجاح")),
      );
      Navigator.pop(context, true); // نرجع إلى صفحة التفاصيل مع إشارة نجاح
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل التحديث: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تعديل بيانات الطبيب")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _specialtyController,
                decoration: const InputDecoration(labelText: "التخصص"),
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: "سنوات الخبرة"),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "الحقل مطلوب";
                  }
                  if (int.tryParse(v.trim()) == null) {
                    return "يرجى إدخال رقم صحيح";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: "ملاحظات"),
                maxLines: 3,
              ),
              const SizedBox(height: 25),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _submitUpdate,
                    child: const Text("حفظ التعديلات"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
