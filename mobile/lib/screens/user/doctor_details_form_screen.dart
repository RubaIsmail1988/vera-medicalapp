import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/details_service.dart';
import '/models/doctor_details.dart';
import '/utils/ui_helpers.dart';

class DoctorDetailsFormScreen extends StatefulWidget {
  final String token; // legacy: kept to avoid breaking callers
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

  int _parseYearsOrZero(String raw) {
    final t = raw.trim();
    final v = int.tryParse(t) ?? 0;
    return v < 0 ? 0 : v;
  }

  Future<void> submitDoctorDetails() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final request = DoctorDetailsRequest(
      userId: widget.userId,
      specialty: specialtyController.text.trim(),
      experienceYears: _parseYearsOrZero(experienceYearsController.text),
      notes:
          notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
    );

    try {
      await DetailsService().createDoctorDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      showAppSuccessSnackBar(context, 'تم حفظ تفاصيل الطبيب بنجاح.');
      context.go('/app/doctor-details');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر حفظ تفاصيل الطبيب.',
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("إدخال تفاصيل الطبيب")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: specialtyController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: "التخصص",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  enabled: !loading,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? "الحقل مطلوب"
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: experienceYearsController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: "سنوات الخبرة",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  enabled: !loading,
                  keyboardType: TextInputType.number,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? "الحقل مطلوب"
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: "ملاحظات",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  enabled: !loading,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : submitDoctorDetails,
                    child:
                        loading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text("حفظ"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
