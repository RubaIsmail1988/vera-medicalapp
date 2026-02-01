import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/utils/api_exception.dart';
import '/utils/ui_helpers.dart';

class HealthProfileTab extends StatefulWidget {
  final String role; // doctor | patient
  final int userId;
  final int? selectedPatientId; // doctor context (patient id)

  const HealthProfileTab({
    super.key,
    required this.role,
    required this.userId,
    required this.selectedPatientId,
  });

  @override
  State<HealthProfileTab> createState() => _HealthProfileTabState();
}

class _HealthProfileTabState extends State<HealthProfileTab> {
  late final AuthService authService;

  bool loading = true;
  Object? fetchError; // unified fetch error
  Map<String, dynamic>? data;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  int get _targetUserId {
    if (isDoctor) return widget.selectedPatientId ?? 0;
    return widget.userId;
  }

  @override
  void initState() {
    super.initState();
    authService = AuthService();
    // ignore: unawaited_futures
    _load();
  }

  @override
  void didUpdateWidget(covariant HealthProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldTarget =
        (oldWidget.role == "doctor")
            ? (oldWidget.selectedPatientId ?? 0)
            : oldWidget.userId;

    final newTarget = _targetUserId;

    if (oldTarget != newTarget) {
      setState(() {
        loading = true;
        fetchError = null;
        data = null;
      });
      // ignore: unawaited_futures
      _load();
    }
  }

  Future<void> _load() async {
    final targetUserId = _targetUserId;

    if (targetUserId <= 0) {
      if (!mounted) return;
      setState(() {
        loading = false;
        fetchError = Exception("لا يوجد مريض محدد لعرض الملف الصحي.");
        data = null;
      });
      return;
    }

    try {
      final res = await authService.authorizedRequest(
        "patient-details/$targetUserId",
        "GET",
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) {
          setState(() {
            data = Map<String, dynamic>.from(decoded);
            loading = false;
            fetchError = null;
          });
          return;
        }

        setState(() {
          loading = false;
          fetchError = Exception("تعذّر قراءة البيانات.");
          data = null;
        });
        return;
      }

      if (res.statusCode == 404) {
        setState(() {
          loading = false;
          fetchError = Exception("لا يوجد ملف صحي لهذا المستخدم بعد.");
          data = null;
        });
        return;
      }

      setState(() {
        loading = false;
        fetchError = ApiException(res.statusCode, res.body);
        data = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        fetchError = e;
        data = null;
      });
    }
  }

  Future<void> _retry() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      fetchError = null;
    });
    await _load();
  }

  // ---------- helpers: hide empty/false ----------
  bool _isEmptyValue(dynamic v) {
    if (v == null) return true;
    if (v is bool) return v == false;
    if (v is num) return v == 0;
    final s = v.toString().trim();
    if (s.isEmpty) return true;
    if (s.toLowerCase() == "null") return true;
    if (s == "-" || s == "0") return true;
    return false;
  }

  String _asText(dynamic v) {
    if (v == null) return "";
    final s = v.toString().trim();
    return s;
  }

  String _formatBmi(dynamic v) {
    if (v == null) return "";
    if (v is num) return v.toStringAsFixed(2);
    final parsed = double.tryParse(v.toString());
    if (parsed == null) return _asText(v);
    return parsed.toStringAsFixed(2);
  }

  String _bpLabel(dynamic sys, dynamic dia) {
    if (sys == null || dia == null) return "";
    return "$sys/$dia";
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }

  Widget _maybeInfoTile({
    required IconData icon,
    required String title,
    required dynamic rawValue,
    String Function(dynamic v)? formatter,
  }) {
    if (_isEmptyValue(rawValue)) return const SizedBox.shrink();
    final text = (formatter != null) ? formatter(rawValue) : _asText(rawValue);
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return _infoTile(icon: icon, title: title, value: text);
  }

  Widget _sectionHeader(String title, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: cs.onSurface),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasAny(List<Widget> tiles) {
    for (final w in tiles) {
      if (w is! SizedBox) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fetchError != null) {
      return AppFetchStateView(error: fetchError!, onRetry: _retry);
    }

    final d = data ?? <String, dynamic>{};

    // ---- raw values from backend ----
    final dob = d["date_of_birth"];
    final height = d["height"];
    final weight = d["weight"];
    final bmi = d["bmi"];

    final gender = d["gender"];
    final bloodType = d["blood_type"];
    final isPregnant = d["is_pregnant"];

    final smokingStatus = d["smoking_status"];
    final cigarettesPerDay = d["cigarettes_per_day"];
    final alcoholUse = d["alcohol_use"];
    final activityLevel = d["activity_level"];

    final hasDiabetes = d["has_diabetes"];
    final hasHypertension = d["has_hypertension"];
    final hasHeartDisease = d["has_heart_disease"];
    final hasAsthmaCopd = d["has_asthma_copd"];
    final hasKidneyDisease = d["has_kidney_disease"];

    final bpSys = d["last_bp_systolic"];
    final bpDia = d["last_bp_diastolic"];
    final lastHba1c = d["last_hba1c"];

    final allergies = d["allergies"];
    final chronic = d["chronic_disease"]; // singular in serializer
    final notes = d["health_notes"];

    // linked display logic (doctor-friendly)
    final showPregnant =
        (gender?.toString() == "female") && (isPregnant == true);
    final showCigarettes =
        (smokingStatus?.toString() == "current") &&
        !_isEmptyValue(cigarettesPerDay);

    // ---- build sections ----
    final tilesBasics = <Widget>[
      _maybeInfoTile(
        icon: Icons.cake_outlined,
        title: "تاريخ الميلاد",
        rawValue: dob,
      ),
      _maybeInfoTile(
        icon: Icons.height_outlined,
        title: "الطول",
        rawValue: height,
      ),
      _maybeInfoTile(
        icon: Icons.monitor_weight_outlined,
        title: "الوزن",
        rawValue: weight,
      ),
      _maybeInfoTile(
        icon: Icons.analytics_outlined,
        title: "BMI",
        rawValue: bmi,
        formatter: _formatBmi,
      ),
      _maybeInfoTile(icon: Icons.wc_outlined, title: "الجنس", rawValue: gender),
      _maybeInfoTile(
        icon: Icons.bloodtype_outlined,
        title: "زمرة الدم",
        rawValue: bloodType,
      ),
      if (showPregnant)
        _infoTile(
          icon: Icons.pregnant_woman_outlined,
          title: "حامل",
          value: "نعم",
        ),
    ];

    final tilesLifestyle = <Widget>[
      _maybeInfoTile(
        icon: Icons.smoking_rooms_outlined,
        title: "حالة التدخين",
        rawValue: smokingStatus,
      ),
      if (showCigarettes)
        _infoTile(
          icon: Icons.local_fire_department_outlined,
          title: "عدد السجائر/يوم",
          value: cigarettesPerDay.toString(),
        ),
      _maybeInfoTile(
        icon: Icons.local_bar_outlined,
        title: "الكحول",
        rawValue: alcoholUse,
      ),
      _maybeInfoTile(
        icon: Icons.directions_run_outlined,
        title: "مستوى النشاط",
        rawValue: activityLevel,
      ),
    ];

    final tilesConditions = <Widget>[
      if (hasDiabetes == true)
        _infoTile(icon: Icons.bloodtype_outlined, title: "سكري", value: "نعم"),
      if (hasHypertension == true)
        _infoTile(icon: Icons.favorite_outline, title: "ضغط", value: "نعم"),
      if (hasHeartDisease == true)
        _infoTile(
          icon: Icons.monitor_heart_outlined,
          title: "أمراض قلب",
          value: "نعم",
        ),
      if (hasAsthmaCopd == true)
        _infoTile(
          icon: Icons.air_outlined,
          title: "ربو/انسداد رئوي",
          value: "نعم",
        ),
      if (hasKidneyDisease == true)
        _infoTile(
          icon: Icons.water_drop_outlined,
          title: "أمراض كلى",
          value: "نعم",
        ),
    ];

    final tilesMeasurements = <Widget>[
      _maybeInfoTile(
        icon: Icons.speed_outlined,
        title: "آخر قراءة ضغط",
        rawValue: _bpLabel(bpSys, bpDia),
      ),
      _maybeInfoTile(
        icon: Icons.science_outlined,
        title: "HbA1c",
        rawValue: lastHba1c,
      ),
    ];

    final tilesNotes = <Widget>[
      _maybeInfoTile(
        icon: Icons.warning_amber_outlined,
        title: "حساسية",
        rawValue: allergies,
      ),
      _maybeInfoTile(
        icon: Icons.medical_information_outlined,
        title: "الأمراض المزمنة",
        rawValue: chronic,
      ),
      _maybeInfoTile(
        icon: Icons.notes_outlined,
        title: "ملاحظات",
        rawValue: notes,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.health_and_safety_outlined),
              title: Text("الملف الصحي"),
            ),
          ),

          // أساسيات
          if (_hasAny(tilesBasics)) ...[
            _sectionHeader("البيانات الأساسية", icon: Icons.person_outline),
            ...tilesBasics,
          ],

          // نمط حياة
          if (_hasAny(tilesLifestyle)) ...[
            _sectionHeader("نمط الحياة", icon: Icons.spa_outlined),
            ...tilesLifestyle,
          ],

          // أمراض/سوابق
          if (_hasAny(tilesConditions)) ...[
            _sectionHeader("سوابق مرضية", icon: Icons.healing_outlined),
            ...tilesConditions,
          ],

          // قياسات متابعة
          if (_hasAny(tilesMeasurements)) ...[
            _sectionHeader("قياسات متابعة", icon: Icons.monitor_heart_outlined),
            ...tilesMeasurements,
          ],

          // ملاحظات
          if (_hasAny(tilesNotes)) ...[
            _sectionHeader("ملاحظات إضافية", icon: Icons.notes_outlined),
            ...tilesNotes,
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
