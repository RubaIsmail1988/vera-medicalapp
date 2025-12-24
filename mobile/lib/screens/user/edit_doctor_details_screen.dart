import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/doctor_details.dart';
import '/utils/ui_helpers.dart';

class EditDoctorDetailsScreen extends StatefulWidget {
  // لن نستخدمه مباشرة إذا DetailsService يستعمل التوكن المخزن
  final String token;
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
  final formKey = GlobalKey<FormState>();

  late final TextEditingController specialtyController;
  late final TextEditingController experienceController;
  late final TextEditingController notesController;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    specialtyController = TextEditingController(text: widget.specialty);
    experienceController = TextEditingController(
      text: widget.experienceYears.toString(),
    );
    notesController = TextEditingController(text: widget.notes ?? '');
  }

  @override
  void dispose() {
    specialtyController.dispose();
    experienceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> submitUpdate() async {
    if (!formKey.currentState!.validate()) return;
    if (loading) return;

    setState(() => loading = true);

    final expYears = int.tryParse(experienceController.text.trim()) ?? 0;

    final request = DoctorDetailsRequest(
      userId: widget.userId,
      specialty: specialtyController.text.trim(),
      experienceYears: expYears,
      notes:
          notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
    );

    final response = await DetailsService().updateDoctorDetails(request);

    if (!mounted) return;
    setState(() => loading = false);

    if (response.statusCode == 200) {
      showAppSnackBar(
        context,
        'تم تحديث بيانات الطبيب بنجاح',
        type: AppSnackBarType.success,
      );
      Navigator.pop(context, true); // نرجع إلى صفحة التفاصيل مع إشارة نجاح
      return;
    }

    showAppSnackBar(
      context,
      'فشل التحديث: ${response.body}',
      type: AppSnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات الطبيب')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: 'التخصص'),
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: experienceController,
                decoration: const InputDecoration(labelText: 'سنوات الخبرة'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return 'الحقل مطلوب';
                  if (int.tryParse(text) == null) return 'يرجى إدخال رقم صحيح';
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
                maxLines: 3,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submitUpdate,
                  child:
                      loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('حفظ التعديلات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
