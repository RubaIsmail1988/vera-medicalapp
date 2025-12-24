import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/patient_details.dart';
import '/utils/ui_helpers.dart';

class EditPatientDetailsScreen extends StatefulWidget {
  final String
  token; // غير مستخدم مباشرة (DetailsService يعتمد على التوكن المخزن)
  final int userId;

  final String dateOfBirth;
  final double? height;
  final double? weight;
  final double? bmi;
  final String? healthNotes;

  const EditPatientDetailsScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.dateOfBirth,
    this.height,
    this.weight,
    this.bmi,
    this.healthNotes,
  });

  @override
  State<EditPatientDetailsScreen> createState() =>
      _EditPatientDetailsScreenState();
}

class _EditPatientDetailsScreenState extends State<EditPatientDetailsScreen> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController dobController;
  late final TextEditingController heightController;
  late final TextEditingController weightController;
  late final TextEditingController notesController;

  bool loading = false;
  double? bmi;

  @override
  void initState() {
    super.initState();

    dobController = TextEditingController(text: widget.dateOfBirth);
    heightController = TextEditingController(
      text: widget.height?.toString() ?? '',
    );
    weightController = TextEditingController(
      text: widget.weight?.toString() ?? '',
    );
    notesController = TextEditingController(text: widget.healthNotes ?? '');
    bmi = widget.bmi;

    // تحديث BMI عند تغير الطول/الوزن بدون استدعاء داخل build
    heightController.addListener(_recalcBmi);
    weightController.addListener(_recalcBmi);

    // حساب أولي (مرة واحدة)
    _recalcBmi();
  }

  @override
  void dispose() {
    dobController.dispose();
    heightController.dispose();
    weightController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _recalcBmi() {
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

  Future<void> submitUpdate() async {
    if (!formKey.currentState!.validate()) return;
    if (loading) return;

    setState(() => loading = true);

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text.trim(),
      height: double.tryParse(heightController.text.trim()),
      weight: double.tryParse(weightController.text.trim()),
      bmi: bmi,
      healthNotes: notesController.text.trim(),
    );

    try {
      final response = await DetailsService().updatePatientDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      if (response.statusCode == 200) {
        showAppSnackBar(
          context,
          'تم تحديث البيانات بنجاح',
          type: AppSnackBarType.success,
        );
        Navigator.pop(context, true);
        return;
      }

      showAppSnackBar(
        context,
        'فشل التحديث: ${response.body}',
        type: AppSnackBarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showAppSnackBar(
        context,
        'تعذّر الاتصال بالخادم. حاول لاحقاً.',
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل بيانات المريض')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: 'تاريخ الميلاد (YYYY-MM-DD)',
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(labelText: 'الطول (سم)'),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'الوزن (كغ)'),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                  color: cs.surfaceContainerHighest,
                ),
                child: Text(
                  'BMI: ${bmi?.toStringAsFixed(2) ?? '--'}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظات صحية'),
                maxLines: 4,
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
