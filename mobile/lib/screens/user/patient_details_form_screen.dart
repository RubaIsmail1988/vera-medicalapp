import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/details_service.dart';
import '/models/patient_details.dart';
import '/utils/ui_helpers.dart';

class PatientDetailsFormScreen extends StatefulWidget {
  final String token;
  final int userId;

  const PatientDetailsFormScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<PatientDetailsFormScreen> createState() =>
      _PatientDetailsFormScreenState();
}

class _PatientDetailsFormScreenState extends State<PatientDetailsFormScreen> {
  final formKey = GlobalKey<FormState>();

  final dobController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final notesController = TextEditingController();
  final chronicController = TextEditingController();

  String? selectedGender;
  String? selectedBloodType;

  bool loading = false;
  double? bmi;

  @override
  void initState() {
    super.initState();
    heightController.addListener(recalcBmi);
    weightController.addListener(recalcBmi);
  }

  void recalcBmi() {
    final h = double.tryParse(heightController.text.trim());
    final w = double.tryParse(weightController.text.trim());

    final nextBmi =
        (h != null && w != null && h > 0)
            ? (w / ((h / 100) * (h / 100)))
            : null;

    if (nextBmi == bmi) return;
    if (!mounted) return;

    setState(() => bmi = nextBmi);
  }

  @override
  void dispose() {
    dobController.dispose();
    heightController.dispose();
    weightController.dispose();
    notesController.dispose();
    chronicController.dispose();
    super.dispose();
  }

  Future<void> submitDetails() async {
    if (!formKey.currentState!.validate()) return;
    if (loading) return;

    setState(() => loading = true);

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text.trim(),
      height: double.tryParse(heightController.text.trim()) ?? 0,
      weight: double.tryParse(weightController.text.trim()) ?? 0,
      bmi: bmi ?? 0,
      gender: selectedGender,
      bloodType: selectedBloodType,
      chronicDisease: chronicController.text.trim(),
      healthNotes: notesController.text.trim(),
    );

    try {
      final response = await DetailsService().createPatientDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        showAppSnackBar(
          context,
          'تم حفظ بيانات المريض بنجاح',
          type: AppSnackBarType.success,
        );

        // رجوع آمن (مثل ما اعتمدنا في شاشة الطبيب)
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go('/app/account');
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

      showAppSnackBar(context, 'حدث خطأ: $e', type: AppSnackBarType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("إدخال تفاصيل المريض")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: "تاريخ الميلاد (YYYY-MM-DD)",
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(labelText: "الطول (سم)"),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(labelText: "الوزن ( (كغ)"),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "BMI: ${bmi?.toStringAsFixed(2) ?? "--"}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "الجنس"),
                value: selectedGender,
                items: const [
                  DropdownMenuItem(value: "male", child: Text("ذكر")),
                  DropdownMenuItem(value: "female", child: Text("أنثى")),
                ],
                onChanged: (val) => setState(() => selectedGender = val),
                validator: (v) => v == null ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "زمرة الدم"),
                value: selectedBloodType,
                items: const [
                  DropdownMenuItem(value: "A+", child: Text("A+")),
                  DropdownMenuItem(value: "A-", child: Text("A-")),
                  DropdownMenuItem(value: "B+", child: Text("B+")),
                  DropdownMenuItem(value: "B-", child: Text("B-")),
                  DropdownMenuItem(value: "AB+", child: Text("AB+")),
                  DropdownMenuItem(value: "AB-", child: Text("AB-")),
                  DropdownMenuItem(value: "O+", child: Text("O+")),
                  DropdownMenuItem(value: "O-", child: Text("O-")),
                ],
                onChanged: (val) => setState(() => selectedBloodType = val),
                validator: (v) => v == null ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: chronicController,
                decoration: const InputDecoration(labelText: "أمراض مزمنة"),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: "ملاحظات صحية"),
                maxLines: 4,
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: loading ? null : submitDetails,
                  child:
                      loading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text("حفظ البيانات"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
