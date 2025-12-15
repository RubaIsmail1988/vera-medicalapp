import 'package:flutter/material.dart';
import '/services/details_service.dart';
import '/models/patient_details.dart';
import 'patient_details_screen.dart';

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
      _AddPatientDetailsScreenState();
}

class _AddPatientDetailsScreenState extends State<PatientDetailsFormScreen> {
  final _formKey = GlobalKey<FormState>();

  TextEditingController dobController = TextEditingController();
  TextEditingController heightController = TextEditingController();
  TextEditingController weightController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController chronicController = TextEditingController();
  String? selectedGender;
  String? selectedBloodType;
  bool loading = false;
  double? bmi;

  void calculateBMI() {
    final h = double.tryParse(heightController.text);
    final w = double.tryParse(weightController.text);

    if (h != null && w != null && h > 0) {
      bmi = w / ((h / 100) * (h / 100));
      setState(() {});
    }
  }

  Future<void> submitDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text,
      height: double.parse(heightController.text),
      weight: double.parse(weightController.text),
      bmi: bmi ?? 0,
      gender: selectedGender,
      bloodType: selectedBloodType,
      chronicDisease: chronicController.text,
      healthNotes: notesController.text,
    );

    final response = await DetailsService().createPatientDetails(request);

    // ✅ حراسة بعد الـ async gap قبل أي استخدام لـ context / setState
    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => PatientDetailsScreen(
                token: widget.token,
                userId: widget.userId,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("فشل الحفظ: ${response.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    calculateBMI(); // لحساب BMI مباشرة أثناء التعديل

    return Scaffold(
      appBar: AppBar(title: const Text("إدخال تفاصيل المريض")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // تاريخ الميلاد
              TextFormField(
                controller: dobController,
                decoration: const InputDecoration(
                  labelText: "تاريخ الميلاد (YYYY-MM-DD)",
                ),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              // الطول
              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(labelText: "الطول (سم)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => calculateBMI()),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              // الوزن
              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(labelText: "الوزن (كغ)"),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() => calculateBMI()),
                validator: (v) => v == null || v.isEmpty ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              // BMI
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

              // الملاحظات الصحية
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(labelText: "ملاحظات صحية"),
                maxLines: 4,
              ),
              const SizedBox(height: 25),

              // زر الحفظ
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: submitDetails,
                    child: const Text("حفظ البيانات"),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
