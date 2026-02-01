import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/details_service.dart';
import '/models/patient_details.dart';
import '/utils/ui_helpers.dart';

class PatientDetailsFormScreen extends StatefulWidget {
  final String token; // legacy
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

  // NEW controllers
  final cigarettesPerDayController = TextEditingController();
  final bpSysController = TextEditingController();
  final bpDiaController = TextEditingController();
  final hba1cController = TextEditingController();
  final allergiesController = TextEditingController();

  String? selectedGender;
  String? selectedBloodType;

  // NEW selections
  String smokingStatus = "never"; // never/former/current
  String alcoholUse = "none"; // none/occasional/regular
  String activityLevel = "moderate"; // low/moderate/high

  // NEW switches
  bool hasDiabetes = false;
  bool hasHypertension = false;
  bool hasHeartDisease = false;
  bool hasAsthmaCopd = false;
  bool hasKidneyDisease = false;

  bool isPregnant = false;

  bool loading = false;
  double? bmi;

  bool get _showCigarettesPerDay => smokingStatus == "current";
  bool get _showPregnant => selectedGender == "female";

  @override
  void initState() {
    super.initState();
    heightController.addListener(recalcBmi);
    weightController.addListener(recalcBmi);
    recalcBmi();
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

    cigarettesPerDayController.dispose();
    bpSysController.dispose();
    bpDiaController.dispose();
    hba1cController.dispose();
    allergiesController.dispose();

    super.dispose();
  }

  double? _parsePositiveDoubleOrNull(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    if (v <= 0) return null;
    return v;
  }

  int? _parseIntOrNull(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _parseDoubleOrNull(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String? _nullIfEmpty(String raw) {
    final v = raw.trim();
    return v.isEmpty ? null : v;
  }

  void _handleGenderChanged(String? val) {
    setState(() {
      selectedGender = val;
      // if not female => force isPregnant false
      if (!_showPregnant) {
        isPregnant = false;
      }
    });
  }

  void _handleSmokingStatusChanged(String? val) {
    setState(() {
      smokingStatus = val ?? "never";
      // if not current => clear cigarettes
      if (!_showCigarettesPerDay) {
        cigarettesPerDayController.text = '';
      }
    });
  }

  Future<void> submitDetails() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    final height = _parsePositiveDoubleOrNull(heightController.text);
    final weight = _parsePositiveDoubleOrNull(weightController.text);

    if (height == null) {
      showAppSnackBar(
        context,
        'يرجى إدخال طول صحيح أكبر من 0.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (weight == null) {
      showAppSnackBar(
        context,
        'يرجى إدخال وزن صحيح أكبر من 0.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (bmi == null) {
      showAppSnackBar(
        context,
        'تعذر حساب BMI. تأكد من إدخال الطول والوزن بشكل صحيح.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => loading = true);

    final request = PatientDetailsRequest(
      userId: widget.userId,
      dateOfBirth: dobController.text.trim(),
      height: height,
      weight: weight,
      bmi: bmi!,
      gender: selectedGender,
      bloodType: selectedBloodType,

      // NEW fields
      smokingStatus: smokingStatus,
      cigarettesPerDay:
          _showCigarettesPerDay
              ? _parseIntOrNull(cigarettesPerDayController.text)
              : null,
      alcoholUse: alcoholUse,
      activityLevel: activityLevel,

      hasDiabetes: hasDiabetes,
      hasHypertension: hasHypertension,
      hasHeartDisease: hasHeartDisease,
      hasAsthmaCopd: hasAsthmaCopd,
      hasKidneyDisease: hasKidneyDisease,

      // linked to gender
      isPregnant: _showPregnant ? isPregnant : false,

      lastBpSystolic: _parseIntOrNull(bpSysController.text),
      lastBpDiastolic: _parseIntOrNull(bpDiaController.text),

      lastHba1c: _parseDoubleOrNull(hba1cController.text),

      allergies: _nullIfEmpty(allergiesController.text),

      chronicDisease: _nullIfEmpty(chronicController.text),
      healthNotes: _nullIfEmpty(notesController.text),
    );

    try {
      await DetailsService().createPatientDetails(request);

      if (!mounted) return;
      setState(() => loading = false);

      showAppSnackBar(
        context,
        'تم حفظ بيانات المريض بنجاح',
        type: AppSnackBarType.success,
      );

      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go('/app/account');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر حفظ بيانات المريض.',
      );
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
                enabled: !loading,
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
                enabled: !loading,
                decoration: const InputDecoration(labelText: "الطول (سم)"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty) ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: weightController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "الوزن (كغ)"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  "BMI: ${bmi?.toStringAsFixed(2) ?? '--'}",
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
                onChanged: loading ? null : _handleGenderChanged,
                validator: (v) => v == null ? "الحقل مطلوب" : null,
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
                onChanged:
                    loading
                        ? null
                        : (val) => setState(() => selectedBloodType = val),
                validator: (v) => v == null ? "الحقل مطلوب" : null,
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "حالة التدخين"),
                value: smokingStatus,
                items: const [
                  DropdownMenuItem(value: "never", child: Text("never")),
                  DropdownMenuItem(value: "former", child: Text("former")),
                  DropdownMenuItem(value: "current", child: Text("current")),
                ],
                onChanged: loading ? null : _handleSmokingStatusChanged,
              ),
              const SizedBox(height: 15),

              // linked field: cigarettes only if current smoker
              if (_showCigarettesPerDay)
                TextFormField(
                  controller: cigarettesPerDayController,
                  enabled: !loading,
                  decoration: const InputDecoration(
                    labelText: "عدد السجائر/يوم",
                  ),
                  keyboardType: TextInputType.number,
                ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "الكحول"),
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
              ),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "مستوى النشاط"),
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
              ),
              const SizedBox(height: 10),

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
                decoration: const InputDecoration(labelText: "ضغط (انقباضي)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: bpDiaController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "ضغط (انبساطي)"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: hba1cController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "HbA1c"),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: allergiesController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "حساسية"),
                maxLines: 2,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: chronicController,
                enabled: !loading,
                decoration: const InputDecoration(labelText: "أمراض مزمنة"),
                maxLines: 2,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: notesController,
                enabled: !loading,
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
