import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '/utils/constants.dart';
import '/utils/ui_helpers.dart';
import 'edit_patient_details_screen.dart';
import 'patient_details_form_screen.dart';
import '/utils/api_exception.dart';

class PatientDetailsScreen extends StatefulWidget {
  final int userId;
  final String token;

  const PatientDetailsScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  Map<String, dynamic>? details;

  bool loading = true;
  bool notFound = false; // 404: لا يوجد تفاصيل
  Object? fetchError; // نخزن الخطأ الخام (بدون عرضه كنص للمستخدم)

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      notFound = false;
      fetchError = null;
      details = null;
    });

    final url = Uri.parse("$accountsBaseUrl/patient-details/${widget.userId}/");

    try {
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer ${widget.token}",
          "Accept": "application/json",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          details = jsonDecode(response.body) as Map<String, dynamic>;
          loading = false;
        });
        return;
      }

      if (response.statusCode == 404) {
        setState(() {
          notFound = true;
          loading = false;
        });
        return;
      }

      setState(() {
        loading = false;
        fetchError = ApiException(response.statusCode, response.body);
      });

      showActionErrorSnackBar(
        context,
        statusCode: response.statusCode,
        data: response.body,
        fallback: 'تعذّر تحميل تفاصيل المريض.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        fetchError = e;
      });

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر تحميل تفاصيل المريض.',
      );
    }
  }

  void openCreateForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PatientDetailsFormScreen(
              token: widget.token,
              userId: widget.userId,
            ),
      ),
    ).then((_) {
      if (!mounted) return;
      fetchDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (notFound) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text("تفاصيل المريض")),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 72, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد بيانات محفوظة لهذا المريض.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'يمكنك إضافة بيانات المريض الآن.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: openCreateForm,
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة البيانات'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(onPressed: _goBack, child: const Text('رجوع')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (details == null) {
      final state = mapFetchExceptionToInlineState(fetchError ?? 'unknown');

      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text("تفاصيل المريض")),
          body: AppInlineErrorState(
            title: state.title,
            message: state.message,
            icon: state.icon,
            onRetry: fetchDetails,
          ),
        ),
      );
    }

    final gender = details!["gender"]?.toString();
    final smokingStatus = details!["smoking_status"]?.toString();

    final showPregnant = gender == "female";
    final showCigarettes = smokingStatus == "current";

    // Values helpers
    final dob = details!["date_of_birth"]?.toString();
    final height = details!["height"];
    final weight = details!["weight"];
    final bmi = details!["bmi"];

    final bloodType = details!["blood_type"]?.toString();

    final alcoholUse = details!["alcohol_use"]?.toString();
    final activityLevel = details!["activity_level"]?.toString();

    final hasDiabetes = details!["has_diabetes"];
    final hasHypertension = details!["has_hypertension"];
    final hasHeartDisease = details!["has_heart_disease"];
    final hasAsthmaCopd = details!["has_asthma_copd"];
    final hasKidneyDisease = details!["has_kidney_disease"];

    final lastBpSys = details!["last_bp_systolic"];
    final lastBpDia = details!["last_bp_diastolic"];

    final lastHba1c = details!["last_hba1c"];

    final allergiesRaw = details!["allergies"]?.toString();
    final chronicRaw = details!["chronic_disease"]?.toString();
    final notesRaw = details!["health_notes"]?.toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("تفاصيل المريض")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              // ---------------- Section: Basic measurements ----------------
              _sectionHeader(
                context,
                'القياسات الأساسية',
                icon: Icons.monitor_weight_outlined,
              ),
              const SizedBox(height: 10),

              _maybeTile(context, title: "تاريخ الميلاد", value: dob),
              _maybeTile(
                context,
                title: "الطول",
                value: _withUnit(height, "سم"),
              ),
              _maybeTile(
                context,
                title: "الوزن",
                value: _withUnit(weight, "كغ"),
              ),
              _maybeTile(context, title: "BMI", value: bmi?.toString()),

              const SizedBox(height: 18),

              // ---------------- Section: General info ----------------
              _sectionHeader(
                context,
                'معلومات عامة',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 10),

              _maybeTile(context, title: "الجنس", value: gender),
              _maybeTile(context, title: "زمرة الدم", value: bloodType),

              if (showPregnant)
                _maybeTile(
                  context,
                  title: "حامل",
                  value: _boolText(details!["is_pregnant"]),
                  hideIfFalse: true,
                ),

              const SizedBox(height: 18),

              // ---------------- Section: Lifestyle ----------------
              _sectionHeader(
                context,
                'نمط الحياة',
                icon: Icons.self_improvement_outlined,
              ),
              const SizedBox(height: 10),

              _maybeTile(context, title: "حالة التدخين", value: smokingStatus),
              if (showCigarettes)
                _maybeTile(
                  context,
                  title: "عدد السجائر/يوم",
                  value: details!["cigarettes_per_day"]?.toString(),
                ),

              _maybeTile(context, title: "الكحول", value: alcoholUse),
              _maybeTile(context, title: "مستوى النشاط", value: activityLevel),

              const SizedBox(height: 18),

              // ---------------- Section: Conditions & readings ----------------
              _sectionHeader(
                context,
                'الحالات والقراءات',
                icon: Icons.health_and_safety_outlined,
              ),
              const SizedBox(height: 10),

              // Hide boolean rows if false/null
              _maybeTile(
                context,
                title: "سكري",
                value: _boolText(hasDiabetes),
                hideIfFalse: true,
              ),
              _maybeTile(
                context,
                title: "ضغط",
                value: _boolText(hasHypertension),
                hideIfFalse: true,
              ),
              _maybeTile(
                context,
                title: "أمراض قلب",
                value: _boolText(hasHeartDisease),
                hideIfFalse: true,
              ),
              _maybeTile(
                context,
                title: "ربو/انسداد رئوي",
                value: _boolText(hasAsthmaCopd),
                hideIfFalse: true,
              ),
              _maybeTile(
                context,
                title: "أمراض كلى",
                value: _boolText(hasKidneyDisease),
                hideIfFalse: true,
              ),

              // Readings (hide if missing)
              _maybeTile(
                context,
                title: "آخر قراءة ضغط",
                value: _bpLabel(lastBpSys, lastBpDia),
                hideIfDash: true,
              ),
              _maybeTile(context, title: "HbA1c", value: lastHba1c?.toString()),

              // Text fields (hide if empty)
              _maybeTile(
                context,
                title: "حساسية",
                value: allergiesRaw,
                treatEmptyAsNull: true,
              ),
              _maybeTile(
                context,
                title: "أمراض مزمنة",
                value: chronicRaw,
                treatEmptyAsNull: true,
              ),
              _maybeTile(
                context,
                title: "ملاحظات صحية",
                value: notesRaw,
                treatEmptyAsNull: true,
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("تعديل البيانات"),
                  onPressed: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => EditPatientDetailsScreen(
                              token: widget.token,
                              userId: widget.userId,
                              dateOfBirth:
                                  details!["date_of_birth"]!.toString(),
                              height: _parseDouble(details!["height"]),
                              weight: _parseDouble(details!["weight"]),
                              bmi: _parseDouble(details!["bmi"]),
                              gender: gender,
                              bloodType: details!["blood_type"]?.toString(),
                              smokingStatus: smokingStatus,
                              cigarettesPerDay: _parseInt(
                                details!["cigarettes_per_day"],
                              ),
                              alcoholUse: details!["alcohol_use"]?.toString(),
                              activityLevel:
                                  details!["activity_level"]?.toString(),
                              hasDiabetes: details!["has_diabetes"] as bool?,
                              hasHypertension:
                                  details!["has_hypertension"] as bool?,
                              hasHeartDisease:
                                  details!["has_heart_disease"] as bool?,
                              hasAsthmaCopd:
                                  details!["has_asthma_copd"] as bool?,
                              hasKidneyDisease:
                                  details!["has_kidney_disease"] as bool?,
                              isPregnant: details!["is_pregnant"] as bool?,
                              lastBpSystolic: _parseInt(
                                details!["last_bp_systolic"],
                              ),
                              lastBpDiastolic: _parseInt(
                                details!["last_bp_diastolic"],
                              ),
                              lastHba1c: _parseDouble(details!["last_hba1c"]),
                              allergies: details!["allergies"]?.toString(),
                              chronicDisease:
                                  details!["chronic_disease"]?.toString(),
                              healthNotes: details!["health_notes"]?.toString(),
                            ),
                      ),
                    );

                    if (!mounted) return;
                    if (updated == true) {
                      await fetchDetails();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goBack,
                  child: const Text('رجوع'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _goBack() {
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/app/account');
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _withUnit(dynamic v, String unit) {
    if (v == null) return "-";
    final s = v.toString().trim();
    if (s.isEmpty || s == "null") return "-";
    return "$s $unit";
  }

  String _boolText(dynamic v) {
    if (v == true) return "نعم";
    if (v == false) return "لا";
    return "-";
  }

  String _bpLabel(dynamic sys, dynamic dia) {
    if (sys == null || dia == null) return "-";
    return "$sys/$dia";
  }

  // ---------------------------------------------------------------------------
  // Section UI
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _maybeTile(
    BuildContext context, {
    required String title,
    required String? value,
    bool hideIfFalse = false,
    bool treatEmptyAsNull = false,
    bool hideIfDash = false,
  }) {
    final v = (value ?? "").trim();

    if (treatEmptyAsNull && v.isEmpty) return const SizedBox.shrink();

    // for boolean tiles passed as "لا"
    if (hideIfFalse && (v.isEmpty || v == "-" || v == "لا")) {
      return const SizedBox.shrink();
    }

    if (hideIfDash && (v.isEmpty || v == "-")) {
      return const SizedBox.shrink();
    }

    return infoTile(context: context, title: title, value: v.isEmpty ? "-" : v);
  }

  // ---------------------------------------------------------------------------
  // Tile (yours)
  // ---------------------------------------------------------------------------

  Widget infoTile({
    required BuildContext context,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;

    final tileColor = cs.surfaceContainerHighest;
    final borderColor = cs.outlineVariant;
    final titleColor = cs.onSurface;
    final valueColor = cs.onSurface.withValues(alpha: 0.85);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(fontSize: 16, color: valueColor),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
