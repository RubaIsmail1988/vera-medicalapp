import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/doctor_details.dart';
import '/utils/ui_helpers.dart';
import 'doctor_details_screen.dart';

class DoctorDetailsFormScreen extends StatefulWidget {
  final String token;
  final int userId;

  const DoctorDetailsFormScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<DoctorDetailsFormScreen> createState() =>
      _DoctorDetailsFormScreenState();
}

class _DoctorDetailsFormScreenState extends State<DoctorDetailsFormScreen> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController specialtyController = TextEditingController();
  final TextEditingController experienceYearsController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool loading = false;

  Future<void> submitDoctorDetails() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final request = DoctorDetailsRequest(
      userId: widget.userId,
      specialty: specialtyController.text.trim(),
      experienceYears: int.tryParse(experienceYearsController.text.trim()) ?? 0,
      notes:
          notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
    );

    try {
      final response = await DetailsService().createDoctorDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        showAppSnackBar(
          context,
          'تم حفظ تفاصيل الطبيب بنجاح.',
          type: AppSnackBarType.success,
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => DoctorDetailsScreen(
                  token: widget.token,
                  userId: widget.userId,
                ),
          ),
        );
        return;
      }

      showAppSnackBar(
        context,
        'فشل الحفظ: ${response.body}',
        type: AppSnackBarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showAppSnackBar(
        context,
        'حدث خطأ أثناء الحفظ: $e',
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    specialtyController.dispose();
    experienceYearsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدخال تفاصيل الطبيب")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: specialtyController,
                decoration: const InputDecoration(labelText: "التخصص"),
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: experienceYearsController,
                decoration: const InputDecoration(labelText: "سنوات الخبرة"),
                keyboardType: TextInputType.number,
                validator:
                    (v) => v == null || v.trim().isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: "ملاحظات"),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: submitDoctorDetails,
                      child: const Text("حفظ"),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
