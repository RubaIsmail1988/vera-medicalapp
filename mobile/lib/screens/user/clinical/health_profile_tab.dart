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
        // نعرضها كـ error "inline" لكن بشكل موحّد
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

      // 404 هنا ليس "انترنت"، بل "لا يوجد ملف صحي" → نعرضه inline برسالة مفهومة.
      if (res.statusCode == 404) {
        setState(() {
          loading = false;
          fetchError = Exception("لا يوجد ملف صحي لهذا المستخدم بعد.");
          data = null;
        });
        return;
      }

      // باقي أكواد HTTP نخزنها كـ ApiException ليتم mapping موحّد في ui_helpers
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

  String _asText(dynamic v) {
    if (v == null) return "غير متوفر";
    final s = v.toString().trim();
    return s.isEmpty ? "غير متوفر" : s;
  }

  String _formatBmi(dynamic v) {
    if (v == null) return "غير متوفر";
    if (v is num) return v.toStringAsFixed(2);
    final parsed = double.tryParse(v.toString());
    if (parsed == null) return _asText(v);
    return parsed.toStringAsFixed(2);
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (fetchError != null) {
      // موحّد + يمنع overflow داخل Tabs
      return AppFetchStateView(error: fetchError!, onRetry: _retry);
    }

    final d = data ?? <String, dynamic>{};

    final dob = _asText(d["date_of_birth"]);
    final height = _asText(d["height"]);
    final weight = _asText(d["weight"]);
    final bmi = _formatBmi(d["bmi"]);
    final gender = _asText(d["gender"]);
    final bloodType = _asText(d["blood_type"]);

    // Serializer field name is "chronic_disease" (singular)
    final chronic = _asText(d["chronic_disease"]);
    final notes = _asText(d["health_notes"]);

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
          const SizedBox(height: 8),

          _infoTile(
            icon: Icons.cake_outlined,
            title: "تاريخ الميلاد",
            value: dob,
          ),
          _infoTile(icon: Icons.height_outlined, title: "الطول", value: height),
          _infoTile(
            icon: Icons.monitor_weight_outlined,
            title: "الوزن",
            value: weight,
          ),
          _infoTile(icon: Icons.analytics_outlined, title: "BMI", value: bmi),

          const SizedBox(height: 8),

          _infoTile(icon: Icons.wc_outlined, title: "الجنس", value: gender),
          _infoTile(
            icon: Icons.bloodtype_outlined,
            title: "زمرة الدم",
            value: bloodType,
          ),
          _infoTile(
            icon: Icons.medical_information_outlined,
            title: "الأمراض المزمنة",
            value: chronic,
          ),
          _infoTile(icon: Icons.notes_outlined, title: "ملاحظات", value: notes),
        ],
      ),
    );
  }
}
