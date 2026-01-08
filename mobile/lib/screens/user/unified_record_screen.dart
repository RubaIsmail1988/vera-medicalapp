import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/ui_helpers.dart';

import 'clinical/orders_tab.dart';
import 'clinical/files_tab.dart';
import 'clinical/prescriptions_tab.dart';
import 'clinical/adherence_tab.dart';
import 'clinical/health_profile_tab.dart';

class UnifiedRecordScreen extends StatefulWidget {
  final String role; // doctor | patient (fallback)
  final int userId;

  const UnifiedRecordScreen({
    super.key,
    required this.role,
    required this.userId,
  });

  @override
  State<UnifiedRecordScreen> createState() => _UnifiedRecordScreenState();
}

class _UnifiedRecordScreenState extends State<UnifiedRecordScreen>
    with SingleTickerProviderStateMixin {
  static const int tabOrders = 0;

  // Single source of truth: tab index <-> route
  static const List<String> _recordTabPaths = <String>[
    "/app/record",
    "/app/record/files",
    "/app/record/prescripts",
    "/app/record/adherence",
    "/app/record/health-profile",
  ];

  late final TabController tabController;
  late final ClinicalService clinicalService;

  // Header
  String currentUserName = "";

  // Role (web-safe)
  late String effectiveRole;

  // Doctor selection
  int? selectedPatientId;
  String? selectedPatientName;

  // Appointment context
  int? selectedAppointmentId;

  // Patients source (dropdown only)
  bool loadingPatients = false;
  String? patientsErrorMessage;
  List<_PatientOption> patientOptions = [];

  // PatientId captured from URL (doctor only)
  int? pendingPatientIdFromUrl;

  bool get isDoctor => effectiveRole == "doctor";
  bool get isPatient => effectiveRole == "patient";

  String get roleLabel {
    if (effectiveRole == "doctor") return "طبيب";
    if (effectiveRole == "patient") return "مريض";
    return effectiveRole;
  }

  @override
  void initState() {
    super.initState();

    effectiveRole = _readRoleFromUrlOrFallback();

    final initialIndex = _initialTabIndexFromUrl();
    tabController = TabController(
      length: _recordTabPaths.length,
      initialIndex: initialIndex,
      vsync: this,
    );

    clinicalService = ClinicalService(authService: AuthService());

    _loadCurrentUserNameFromPrefs();

    // Read appointmentId from URL once
    selectedAppointmentId = _readAppointmentIdFromUrl();

    // Capture patientId from URL (doctor only)
    _capturePatientIdFromUrlIfAny();

    // IMPORTANT FIX:
    // If doctor has patientId in URL, accept it immediately even if no Orders exist.
    if (isDoctor && pendingPatientIdFromUrl != null) {
      final pid = pendingPatientIdFromUrl!;
      selectedPatientId = pid;
      selectedPatientName = "مريض #$pid";
      pendingPatientIdFromUrl = null;

      // Optional: still load dropdown patients (from orders) for later switching
      loadingPatients = true;
      patientsErrorMessage = null;
      _loadDoctorPatientsFromOrders();
    } else if (isDoctor) {
      // Old behavior: show dropdown based on orders list
      loadingPatients = true;
      patientsErrorMessage = null;
      _loadDoctorPatientsFromOrders();
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _loadCurrentUserNameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString("currentUserName") ?? "").trim();

    if (!mounted) return;
    setState(() {
      currentUserName = name;
    });
  }

  // ---------------------------------------------------------------------------
  // URL helpers (web hash-safe)
  // ---------------------------------------------------------------------------

  String _readHashPathOrPath() {
    // Hash routing: "#/app/record/adherence?patientId=31"
    final frag = Uri.base.fragment;
    if (frag.trim().isNotEmpty) {
      final qIndex = frag.indexOf("?");
      return qIndex == -1 ? frag : frag.substring(0, qIndex);
    }

    final p = Uri.base.path;
    return p.isNotEmpty ? p : "/app/record";
  }

  Map<String, String> _readQueryParamsHashSafe() {
    // Normal query
    final direct = Uri.base.queryParameters;
    if (direct.isNotEmpty) return direct;

    // Hash: #/app/record?... (need parse query from fragment)
    final frag = Uri.base.fragment;
    final qIndex = frag.indexOf("?");
    if (qIndex == -1) return const {};

    final fragQuery = frag.substring(qIndex + 1);
    final fake = Uri.parse("http://dummy/?$fragQuery");
    return fake.queryParameters;
  }

  String _readRoleFromUrlOrFallback() {
    final qp = _readQueryParamsHashSafe();
    final fromUrl = (qp["role"] ?? "").trim().toLowerCase();
    if (fromUrl == "doctor") return "doctor";
    if (fromUrl == "patient") return "patient";

    final w = widget.role.trim().toLowerCase();
    return (w == "doctor") ? "doctor" : "patient";
  }

  int _initialTabIndexFromUrl() {
    final path = _readHashPathOrPath();

    for (int i = 0; i < _recordTabPaths.length; i++) {
      final candidate = _recordTabPaths[i];
      if (path == candidate || path.endsWith(candidate)) {
        return i;
      }
    }

    return tabOrders;
  }

  int? _readPatientIdFromUrl() {
    final qp = _readQueryParamsHashSafe();
    final pid = int.tryParse(qp["patientId"] ?? "");
    if (pid != null && pid > 0) return pid;
    return null;
  }

  int? _readAppointmentIdFromUrl() {
    final qp = _readQueryParamsHashSafe();
    final aid = int.tryParse(qp["appointmentId"] ?? "");
    if (aid != null && aid > 0) return aid;
    return null;
  }

  void _capturePatientIdFromUrlIfAny() {
    if (!isDoctor) return;
    pendingPatientIdFromUrl = _readPatientIdFromUrl();
  }

  void _applyPendingPatientSelectionIfPossible() {
    if (!isDoctor) return;

    if (selectedPatientId != null) {
      pendingPatientIdFromUrl = null;
      return;
    }

    final pid = pendingPatientIdFromUrl;
    if (pid == null) return;

    if (loadingPatients) return;
    if (patientOptions.isEmpty) return;

    final match = patientOptions.where((p) => p.id == pid).toList();
    if (match.isEmpty) return;

    pendingPatientIdFromUrl = null;

    if (!mounted) return;
    setState(() {
      selectedPatientId = pid;
      selectedPatientName = match.first.name;
    });
  }

  String _buildRecordLocationForTab(int index) {
    final safeIndex =
        (index >= 0 && index < _recordTabPaths.length) ? index : tabOrders;

    final base = _recordTabPaths[safeIndex];

    final qp = <String, String>{};

    // WEB-SAFE: always keep role
    qp["role"] = effectiveRole;

    // keep patientId for doctor
    final pid = isDoctor ? selectedPatientId : null;
    if (pid != null && pid > 0) qp["patientId"] = "$pid";

    // keep appointmentId for both roles
    final apptId = selectedAppointmentId;
    if (apptId != null && apptId > 0) qp["appointmentId"] = "$apptId";

    return "$base?${Uri(queryParameters: qp).query}";
  }

  // ---------------------------------------------------------------------------
  // Load patients (doctor) - still from orders (dropdown only)
  // ---------------------------------------------------------------------------

  Future<void> _loadDoctorPatientsFromOrders() async {
    final res = await clinicalService.listOrders();
    if (!mounted) return;

    if (res.statusCode != 200) {
      final msg =
          (res.statusCode == 401)
              ? "انتهت الجلسة، يرجى تسجيل الدخول مجددًا."
              : (res.statusCode == 403)
              ? "لا تملك الصلاحية لعرض المرضى."
              : "تعذر تحميل المرضى (${res.statusCode}).";

      setState(() {
        loadingPatients = false;
        patientsErrorMessage = msg;
      });

      showAppSnackBar(context, msg, type: AppSnackBarType.error);
      return;
    }

    final decoded = jsonDecode(res.body);
    final List<Map<String, dynamic>> list =
        decoded is List
            ? decoded.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    final Map<int, String> byId = {};

    for (final o in list) {
      final pid = _asInt(o["patient"]);
      if (pid == null || pid <= 0) continue;

      final name = (o["patient_display_name"]?.toString() ?? "").trim();
      if (name.isNotEmpty) {
        byId[pid] = name;
      } else {
        byId.putIfAbsent(pid, () => "مريض #$pid");
      }
    }

    final options =
        byId.entries
            .map((e) => _PatientOption(id: e.key, name: e.value))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (!mounted) return;
    setState(() {
      patientOptions = options;
      loadingPatients = false;
      patientsErrorMessage = null;

      // If we already selected patientId from URL earlier, try to improve name
      if (isDoctor && selectedPatientId != null) {
        final m = options.where((x) => x.id == selectedPatientId).toList();
        if (m.isNotEmpty) selectedPatientName = m.first.name;
      }
    });

    _applyPendingPatientSelectionIfPossible();
  }

  // ---------------------------------------------------------------------------
  // UI building blocks
  // ---------------------------------------------------------------------------

  Widget _headerTile({required String titleText}) {
    return Material(
      child: ListTile(
        leading: const Icon(Icons.folder_shared),
        title: Text(titleText),
      ),
    );
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
    required AppSnackBarType tone,
    Widget? action,
  }) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    Color fg;

    switch (tone) {
      case AppSnackBarType.success:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
        break;
      case AppSnackBarType.warning:
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        break;
      case AppSnackBarType.error:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case AppSnackBarType.info:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        break;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: bg,
                  child: Icon(icon, color: fg),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (action != null) ...[const SizedBox(height: 12), action],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check_circle_outline),
        label: Text(label),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    _applyPendingPatientSelectionIfPossible();

    final doctorLabel =
        currentUserName.isNotEmpty ? "د. $currentUserName" : "د. -";

    // Doctor must select patient first ONLY if no patientId exists in URL
    if (isDoctor && selectedPatientId == null) {
      return Column(
        children: [
          _headerTile(titleText: "الدور: $roleLabel | الطبيب: $doctorLabel"),
          Expanded(
            child:
                loadingPatients
                    ? _stateCard(
                      icon: Icons.hourglass_top,
                      title: "جاري التحميل",
                      message: "يتم تحميل قائمة المرضى المرتبطين بطلباتك…",
                      tone: AppSnackBarType.info,
                      action: const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: CircularProgressIndicator(),
                      ),
                    )
                    : (patientsErrorMessage != null)
                    ? _stateCard(
                      icon: Icons.error_outline,
                      title: "تعذر تحميل المرضى",
                      message: patientsErrorMessage!,
                      tone: AppSnackBarType.error,
                      action: _primaryButton(
                        label: "إعادة المحاولة",
                        icon: Icons.refresh,
                        onPressed: () {
                          setState(() {
                            loadingPatients = true;
                            patientsErrorMessage = null;
                          });
                          _loadDoctorPatientsFromOrders();
                        },
                      ),
                    )
                    : (patientOptions.isEmpty)
                    ? _stateCard(
                      icon: Icons.people_outline,
                      title: "لا يوجد مرضى في القائمة",
                      message:
                          "لا توجد طلبات حتى الآن (القائمة تُبنى من الطلبات).\n"
                          "لكن إذا فتحت الإضبارة من الموعد سيتم تمرير patientId وستُفتح الإضبارة مباشرة.",
                      tone: AppSnackBarType.warning,
                    )
                    : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "اختر مريضًا لعرض الإضبارة",
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: "المريض",
                                      border: OutlineInputBorder(),
                                    ),
                                    items:
                                        patientOptions
                                            .map(
                                              (p) => DropdownMenuItem<int>(
                                                value: p.id,
                                                child: Text(
                                                  p.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      if (v == null) return;

                                      final match =
                                          patientOptions
                                              .where((x) => x.id == v)
                                              .toList();
                                      final name =
                                          match.isNotEmpty
                                              ? match.first.name
                                              : "مريض #$v";

                                      setState(() {
                                        selectedPatientId = v;
                                        selectedPatientName = name;
                                      });

                                      context.go(
                                        _buildRecordLocationForTab(
                                          tabController.index,
                                        ),
                                      );

                                      showAppSnackBar(
                                        context,
                                        "تم اختيار المريض: $name",
                                        type: AppSnackBarType.success,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _stateCard(
                            icon: Icons.info_outline,
                            title: "ملاحظة",
                            message:
                                "سيتم استخدام هذا الاختيار لعرض الطلبات والملفات والوصفات والالتزام الدوائي والملف الصحي.",
                            tone: AppSnackBarType.info,
                          ),
                        ],
                      ),
                    ),
          ),
        ],
      );
    }

    final int? patientContextId = isDoctor ? selectedPatientId : widget.userId;

    final subtitleText =
        isPatient
            ? "المريض: ${currentUserName.isNotEmpty ? currentUserName : "-"}"
            : "الطبيب: $doctorLabel | المريض: ${(selectedPatientName?.trim().isNotEmpty ?? false) ? selectedPatientName!.trim() : (selectedPatientId != null ? "مريض #$selectedPatientId" : "-")}";

    final apptId = selectedAppointmentId;
    final hasAppt = apptId != null && apptId > 0;
    final apptKey = (selectedAppointmentId ?? 0);

    return Column(
      children: [
        _headerTile(titleText: subtitleText),

        // Appointment context banner
        if (hasAppt)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: Text("سياق الموعد: #$apptId"),
                subtitle: const Text(
                  "يتم عرض العناصر المرتبطة بهذا الموعد فقط.",
                ),
                trailing: TextButton(
                  onPressed: () {
                    setState(() {
                      selectedAppointmentId = null;
                    });
                    context.go(_buildRecordLocationForTab(tabController.index));
                  },
                  child: const Text("إلغاء الفلتر"),
                ),
              ),
            ),
          ),

        TabBar(
          controller: tabController,
          isScrollable: true,
          onTap: (index) {
            if (isDoctor && selectedPatientId == null) {
              showAppSnackBar(
                context,
                "اختر مريضًا أولاً لعرض الإضبارة.",
                type: AppSnackBarType.warning,
              );
              return;
            }
            context.go(_buildRecordLocationForTab(index));
          },
          tabs: const [
            Tab(text: "الطلبات"),
            Tab(text: "الملفات"),
            Tab(text: "الوصفات"),
            Tab(text: "الالتزام"),
            Tab(text: "الملف الصحي"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              OrdersTab(
                key: ValueKey<String>("orders-$patientContextId-$apptKey"),
                role: effectiveRole,
                userId: widget.userId,
                selectedPatientId: patientContextId,
                selectedAppointmentId: selectedAppointmentId,
              ),
              FilesTab(
                key: ValueKey<String>(
                  "files-$patientContextId-${selectedAppointmentId ?? 0}",
                ),
                role: effectiveRole,
                userId: widget.userId,
                selectedPatientId: patientContextId,
                selectedAppointmentId: selectedAppointmentId,
              ),
              PrescriptionsTab(
                key: ValueKey<String>(
                  "prescriptions-$patientContextId-$apptKey",
                ),
                role: effectiveRole,
                userId: widget.userId,
                selectedPatientId: patientContextId,
                selectedAppointmentId: selectedAppointmentId,
              ),
              AdherenceTab(
                key: ValueKey<String>(
                  "adherence-$patientContextId-${selectedAppointmentId ?? 0}",
                ),
                role: effectiveRole,
                userId: widget.userId,
                selectedPatientId: patientContextId,
                selectedAppointmentId: selectedAppointmentId,
              ),
              HealthProfileTab(
                key: ValueKey<String>("health-profile-$patientContextId"),
                role: effectiveRole,
                userId: widget.userId,
                selectedPatientId: patientContextId,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PatientOption {
  final int id;
  final String name;

  const _PatientOption({required this.id, required this.name});
}
