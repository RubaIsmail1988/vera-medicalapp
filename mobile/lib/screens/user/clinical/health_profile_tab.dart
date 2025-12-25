import 'dart:convert';

import 'package:flutter/material.dart';

import '/services/auth_service.dart';
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
  String? errorMessage;
  Map<String, dynamic>? data;

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  int get _targetUserId {
    if (isDoctor) {
      return widget.selectedPatientId ?? 0;
    }
    return widget.userId;
  }

  @override
  void initState() {
    super.initState();
    authService = AuthService();
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
        errorMessage = null;
        data = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final targetUserId = _targetUserId;
    if (targetUserId <= 0) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = "لا يوجد مريض محدد لعرض الملف الصحي.";
      });
      return;
    }

    final res = await authService.authorizedRequest(
      "patient-details/$targetUserId",
      "GET",
    );

    if (!mounted) return;

    if (res.statusCode == 200) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          setState(() {
            data = decoded;
            loading = false;
            errorMessage = null;
          });
          return;
        }
      } catch (_) {
        // fall-through
      }

      setState(() {
        loading = false;
        errorMessage = "تعذر قراءة البيانات.";
      });
      return;
    }

    final msg =
        (res.statusCode == 401)
            ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
            : (res.statusCode == 403)
            ? "لا تملك الصلاحية لعرض الملف الصحي."
            : (res.statusCode == 404)
            ? "لا يوجد ملف صحي لهذا المستخدم بعد."
            : "فشل تحميل الملف الصحي (${res.statusCode}).";

    setState(() {
      loading = false;
      errorMessage = msg;
    });

    showAppSnackBar(context, msg, type: AppSnackBarType.error);
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

  Widget _stateView({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
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

    if (errorMessage != null) {
      return _stateView(
        icon: Icons.error_outline,
        title: "تعذر عرض الملف الصحي",
        message: errorMessage!,
        action: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                loading = true;
                errorMessage = null;
              });
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text("إعادة المحاولة"),
          ),
        ),
      );
    }

    final d = data ?? {};

    final dob = _asText(d["date_of_birth"]);
    final height = _asText(d["height"]);
    final weight = _asText(d["weight"]);
    final bmi = _formatBmi(d["bmi"]);
    final gender = _asText(d["gender"]);
    final bloodType = _asText(d["blood_type"]);

    // Serializer field name is "chronic_disease" (singular)
    final chronic = _asText(d["chronic_disease"]);
    final notes = _asText(d["health_notes"]);

    final titleText = isDoctor ? "الملف الصحي " : "الملف الصحي ";

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(titleText),
              // subtitle: Text("User ID: $_targetUserId"),
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
            title: "فصيلة الدم",
            value: bloodType,
          ),
          _infoTile(
            icon: Icons.medical_information_outlined,
            title: "الأمراض المزمنة",
            value: chronic,
          ),
          _infoTile(
            icon: Icons.notes_outlined,
            title: "ملاحظات صحية",
            value: notes,
          ),
        ],
      ),
    );
  }
}
