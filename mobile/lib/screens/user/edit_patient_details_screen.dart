import 'package:flutter/material.dart';
import '/services/details_service.dart';
import '/models/patient_details.dart';

class EditPatientDetailsScreen extends StatefulWidget {
  final String token;
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
  final _formKey = GlobalKey<FormState>();

  late TextEditingController dobController;
  late TextEditingController heightController;
  late TextEditingController weightController;
  late TextEditingController notesController;

  bool loading = false;
  double? bmi;

  @override
  void initState() {
    super.initState();
    dobController = TextEditingController(text: widget.dateOfBirth);
    heightController = TextEditingController(
      text: widget.height?.toString() ?? "",
    );
    weightController = TextEditingController(
      text: widget.weight?.toString() ?? "",
    );
    notesController = TextEditingController(text: widget.healthNotes ?? "");
    bmi = widget.bmi;
  }

  void calculateBMI() {
    final h = double.tryParse(heightController.text);
    final w = double.tryParse(weightController.text);

    if (h != null && w != null && h > 0) {
      bmi = w / ((h / 100) * (h / 100));
      setState(() {});
    }
  }

  Future<void> submitUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text,
      height: double.tryParse(heightController.text),
      weight: double.tryParse(weightController.text),
      bmi: bmi,
      healthNotes: notesController.text.trim(),
    );

    final response = await DetailsService().updatePatientDetails(request);

    setState(() => loading = false);

    if (response.statusCode == 200) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم تحديث البيانات بنجاح")));

      Navigator.pop(context, true); // يرجع إلى صفحة التفاصيل
    } else {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل التحديث: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    calculateBMI();

    return Scaffold(
      appBar: AppBar(title: const Text("تعديل بيانات المريض")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: "تاريخ الميلاد (YYYY-MM-DD)",
                ),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(labelText: "الطول (سم)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculateBMI(),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(labelText: "الوزن (كغ)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => calculateBMI(),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "BMI: ${bmi?.toStringAsFixed(2) ?? "--"}",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: "ملاحظات صحية"),
                maxLines: 4,
              ),
              const SizedBox(height: 25),

              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: submitUpdate,
                    child: const Text("حفظ التعديلات"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
