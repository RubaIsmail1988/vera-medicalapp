import 'package:flutter/material.dart';

import '/services/details_service.dart';
import '/models/patient_details.dart';
import '/utils/ui_helpers.dart';

class EditPatientDetailsScreen extends StatefulWidget {
  final String token; // legacy
  final int userId;

  final String dateOfBirth;
  final double? height;
  final double? weight;
  final double? bmi;

  // Existing
  final String? healthNotes;

  // NEW fields (matching backend)
  final String? gender;
  final String? bloodType;

  final String? smokingStatus; // "never" | "former" | "current"
  final int? cigarettesPerDay;

  final String? alcoholUse; // "none" | "occasional" | "regular"
  final String? activityLevel; // "low" | "moderate" | "high"

  final bool? hasDiabetes;
  final bool? hasHypertension;
  final bool? hasHeartDisease;
  final bool? hasAsthmaCopd;
  final bool? hasKidneyDisease;

  final bool? isPregnant;

  final int? lastBpSystolic;
  final int? lastBpDiastolic;

  final double? lastHba1c;

  final String? allergies;
  final String? chronicDisease;

  const EditPatientDetailsScreen({
    super.key,
    required this.token,
    required this.userId,
    required this.dateOfBirth,
    this.height,
    this.weight,
    this.bmi,
    this.healthNotes,

    // NEW
    this.gender,
    this.bloodType,
    this.smokingStatus,
    this.cigarettesPerDay,
    this.alcoholUse,
    this.activityLevel,
    this.hasDiabetes,
    this.hasHypertension,
    this.hasHeartDisease,
    this.hasAsthmaCopd,
    this.hasKidneyDisease,
    this.isPregnant,
    this.lastBpSystolic,
    this.lastBpDiastolic,
    this.lastHba1c,
    this.allergies,
    this.chronicDisease,
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

  // NEW controllers
  late final TextEditingController cigarettesPerDayController;
  late final TextEditingController bpSysController;
  late final TextEditingController bpDiaController;
  late final TextEditingController hba1cController;
  late final TextEditingController allergiesController;
  late final TextEditingController chronicDiseaseController;

  // NEW dropdown/switch state
  String? gender;
  String? bloodType;
  String smokingStatus = "never";
  String alcoholUse = "none";
  String activityLevel = "moderate";

  bool hasDiabetes = false;
  bool hasHypertension = false;
  bool hasHeartDisease = false;
  bool hasAsthmaCopd = false;
  bool hasKidneyDisease = false;
  bool isPregnant = false;

  bool loading = false;
  double? bmi;

  bool get _showCigarettesPerDay => smokingStatus == "current";
  bool get _showPregnant => gender == "female";

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

    // initial values
    gender = widget.gender;
    bloodType = widget.bloodType;

    smokingStatus = (widget.smokingStatus ?? "never");
    alcoholUse = (widget.alcoholUse ?? "none");
    activityLevel = (widget.activityLevel ?? "moderate");

    hasDiabetes = widget.hasDiabetes ?? false;
    hasHypertension = widget.hasHypertension ?? false;
    hasHeartDisease = widget.hasHeartDisease ?? false;
    hasAsthmaCopd = widget.hasAsthmaCopd ?? false;
    hasKidneyDisease = widget.hasKidneyDisease ?? false;

    // enforce initial pregnancy consistency in UI
    isPregnant = (_showPregnant) ? (widget.isPregnant ?? false) : false;

    cigarettesPerDayController = TextEditingController(
      text:
          (_showCigarettesPerDay ? widget.cigarettesPerDay?.toString() : '') ??
          '',
    );

    bpSysController = TextEditingController(
      text: widget.lastBpSystolic?.toString() ?? '',
    );
    bpDiaController = TextEditingController(
      text: widget.lastBpDiastolic?.toString() ?? '',
    );
    hba1cController = TextEditingController(
      text: widget.lastHba1c?.toString() ?? '',
    );
    allergiesController = TextEditingController(text: widget.allergies ?? '');
    chronicDiseaseController = TextEditingController(
      text: widget.chronicDisease ?? '',
    );

    heightController.addListener(_recalcBmi);
    weightController.addListener(_recalcBmi);
    _recalcBmi();
  }

  @override
  void dispose() {
    dobController.dispose();
    heightController.dispose();
    weightController.dispose();
    notesController.dispose();

    cigarettesPerDayController.dispose();
    bpSysController.dispose();
    bpDiaController.dispose();
    hba1cController.dispose();
    allergiesController.dispose();
    chronicDiseaseController.dispose();

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

  void _handleGenderChanged(String? v) {
    setState(() {
      gender = v;
      if (!_showPregnant) {
        isPregnant = false;
      }
    });
  }

  void _handleSmokingStatusChanged(String? v) {
    setState(() {
      smokingStatus = v ?? "never";
      if (!_showCigarettesPerDay) {
        cigarettesPerDayController.text = '';
      }
    });
  }

  int? _parseIntController(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _parseDoubleController(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? _nullIfEmpty(String s) {
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> submitUpdate() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text.trim(),
      height: double.tryParse(heightController.text.trim()),
      weight: double.tryParse(weightController.text.trim()),
      bmi: bmi,

      gender: gender,
      bloodType: bloodType,

      smokingStatus: smokingStatus,
      cigarettesPerDay:
          _showCigarettesPerDay
              ? _parseIntController(cigarettesPerDayController)
              : null,

      alcoholUse: alcoholUse,
      activityLevel: activityLevel,

      hasDiabetes: hasDiabetes,
      hasHypertension: hasHypertension,
      hasHeartDisease: hasHeartDisease,
      hasAsthmaCopd: hasAsthmaCopd,
      hasKidneyDisease: hasKidneyDisease,

      isPregnant: _showPregnant ? isPregnant : false,

      lastBpSystolic: _parseIntController(bpSysController),
      lastBpDiastolic: _parseIntController(bpDiaController),
      lastHba1c: _parseDoubleController(hba1cController),

      allergies: _nullIfEmpty(allergiesController.text),
      chronicDisease: _nullIfEmpty(chronicDiseaseController.text),

      healthNotes: _nullIfEmpty(notesController.text),
    );

    try {
      await DetailsService().updatePatientDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      showAppSnackBar(
        context,
        'تم تحديث البيانات بنجاح',
        type: AppSnackBarType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل تحديث بيانات المريض.',
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
                enabled: !loading,
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
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'الطول (سم)'),
                keyboardType: TextInputType.number,
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? 'الحقل مطلوب' : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: weightController,
                enabled: !loading,
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

              DropdownButtonFormField<String>(
                value: gender,
                items: const [
                  DropdownMenuItem(value: "male", child: Text("male")),
                  DropdownMenuItem(value: "female", child: Text("female")),
                ],
                onChanged: loading ? null : _handleGenderChanged,
                decoration: const InputDecoration(labelText: 'الجنس'),
              ),
              const SizedBox(height: 15),

              // linked field: pregnant only if female
              if (_showPregnant)
                SwitchListTile(
                  value: isPregnant,
                  onChanged:
                      loading ? null : (v) => setState(() => isPregnant = v),
                  title: const Text('حامل'),
                ),

              DropdownButtonFormField<String>(
                value: bloodType,
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
                onChanged:
                    loading ? null : (v) => setState(() => bloodType = v),
                decoration: const InputDecoration(labelText: 'زمرة الدم'),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: smokingStatus,
                items: const [
                  DropdownMenuItem(value: "never", child: Text("never")),
                  DropdownMenuItem(value: "former", child: Text("former")),
                  DropdownMenuItem(value: "current", child: Text("current")),
                ],
                onChanged: loading ? null : _handleSmokingStatusChanged,
                decoration: const InputDecoration(labelText: 'حالة التدخين'),
              ),
              const SizedBox(height: 15),

              // linked field: cigarettes only if current smoker
              if (_showCigarettesPerDay)
                TextFormField(
                  controller: cigarettesPerDayController,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: 'عدد السجائر/يوم',
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: alcoholUse,
                items: const [
                  DropdownMenuItem(value: "none", child: Text("none")),
                  DropdownMenuItem(
                    value: "occasional",
                    child: Text("occasional"),
                  ),
                  DropdownMenuItem(value: "regular", child: Text("regular")),
                ],
                onChanged:
                    loading
                        ? null
                        : (v) => setState(() => alcoholUse = v ?? "none"),
                decoration: const InputDecoration(labelText: 'الكحول'),
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: activityLevel,
                items: const [
                  DropdownMenuItem(value: "low", child: Text("low")),
                  DropdownMenuItem(value: "moderate", child: Text("moderate")),
                  DropdownMenuItem(value: "high", child: Text("high")),
                ],
                onChanged:
                    loading
                        ? null
                        : (v) =>
                            setState(() => activityLevel = v ?? "moderate"),
                decoration: const InputDecoration(labelText: 'مستوى النشاط'),
              ),
              const SizedBox(height: 15),

              SwitchListTile(
                value: hasDiabetes,
                onChanged:
                    loading ? null : (v) => setState(() => hasDiabetes = v),
                title: const Text('سكري'),
              ),
              SwitchListTile(
                value: hasHypertension,
                onChanged:
                    loading ? null : (v) => setState(() => hasHypertension = v),
                title: const Text('ضغط'),
              ),
              SwitchListTile(
                value: hasHeartDisease,
                onChanged:
                    loading ? null : (v) => setState(() => hasHeartDisease = v),
                title: const Text('أمراض قلب'),
              ),
              SwitchListTile(
                value: hasAsthmaCopd,
                onChanged:
                    loading ? null : (v) => setState(() => hasAsthmaCopd = v),
                title: const Text('ربو/انسداد رئوي'),
              ),
              SwitchListTile(
                value: hasKidneyDisease,
                onChanged:
                    loading
                        ? null
                        : (v) => setState(() => hasKidneyDisease = v),
                title: const Text('أمراض كلى'),
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: bpSysController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'ضغط (انقباضي)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: bpDiaController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'ضغط (انبساطي)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: hba1cController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'HbA1c'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: allergiesController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'حساسية'),
                maxLines: 2,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: chronicDiseaseController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: 'أمراض مزمنة'),
                maxLines: 2,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: notesController,
                enabled: !loading,
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
