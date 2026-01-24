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

  // Patient tabs (5)
  static const List<String> _patientRecordTabPaths = <String>[
    "/app/record",
    "/app/record/files",
    "/app/record/prescripts",
    "/app/record/adherence",
    "/app/record/health-profile",
  ];

  // Doctor tabs (4) — NO files
  static const List<String> _doctorRecordTabPaths = <String>[
    "/app/record",
    "/app/record/prescripts",
    "/app/record/adherence",
    "/app/record/health-profile",
  ];

  late TabController tabController;
  late final ClinicalService clinicalService;

  String currentUserName = "";

  late String effectiveRole;

  int? selectedPatientId;
  String? selectedPatientName;

  int? selectedAppointmentId;

  bool loadingPatients = false;
  String? patientsErrorMessage;
  List<_PatientOption> patientOptions = [];

  bool _initializedFromRoute = false;

  bool get isDoctor => effectiveRole == "doctor";
  bool get isPatient => effectiveRole == "patient";

  List<String> get _recordTabPaths =>
      isDoctor ? _doctorRecordTabPaths : _patientRecordTabPaths;

  String get roleLabel {
    if (effectiveRole == "doctor") return "طبيب";
    if (effectiveRole == "patient") return "مريض";
    return effectiveRole;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  @override
  void initState() {
    super.initState();

    // مبدئيًا نستخدم role من widget (سيتم تصحيحه من route في didChangeDependencies)
    effectiveRole =
        widget.role.trim().toLowerCase() == "doctor" ? "doctor" : "patient";

    tabController = TabController(
      length: _recordTabPaths.length,
      initialIndex: tabOrders,
      vsync: this,
    );

    clinicalService = ClinicalService(authService: AuthService());
    _loadCurrentUserNameFromPrefs();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserNameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString("currentUserName") ?? "").trim();

    if (!mounted) return;
    setState(() => currentUserName = name);
  }

  // ---------------------------------------------------------------------------
  // IMPORTANT: read route from GoRouterState (works on mobile + web)
  // ---------------------------------------------------------------------------

  GoRouterState _state() => GoRouterState.of(context);

  String _readRoleFromStateOrFallback() {
    final qp = _state().uri.queryParameters;
    final fromUrl = (qp["role"] ?? "").trim().toLowerCase();
    if (fromUrl == "doctor") return "doctor";
    if (fromUrl == "patient") return "patient";

    final w = widget.role.trim().toLowerCase();
    return (w == "doctor") ? "doctor" : "patient";
  }

  int _tabIndexFromStatePath(List<String> paths) {
    final path = _state().uri.path;

    for (int i = 0; i < paths.length; i++) {
      if (path == paths[i]) return i;
    }
    return tabOrders;
  }

  int? _readPatientIdFromState() {
    final qp = _state().uri.queryParameters;
    final pid = int.tryParse((qp["patientId"] ?? "").trim());
    if (pid != null && pid > 0) return pid;
    return null;
  }

  int? _readAppointmentIdFromState() {
    final qp = _state().uri.queryParameters;
    final aid = int.tryParse((qp["appointmentId"] ?? "").trim());
    if (aid != null && aid > 0) return aid;
    return null;
  }

  String _buildRecordLocationForTab(int index) {
    final paths = _recordTabPaths;

    final safeIndex = (index >= 0 && index < paths.length) ? index : tabOrders;
    final base = paths[safeIndex];

    final qp = <String, String>{};
    qp["role"] = effectiveRole;

    if (isDoctor && selectedPatientId != null && selectedPatientId! > 0) {
      qp["patientId"] = "${selectedPatientId!}";
    }

    if (selectedAppointmentId != null && selectedAppointmentId! > 0) {
      qp["appointmentId"] = "${selectedAppointmentId!}";
    }

    return "$base?${Uri(queryParameters: qp).query}";
  }

  // ---------------------------------------------------------------------------
  // Load patients list for doctor (dropdown only)
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

      if (selectedPatientId != null) {
        final m = options.where((x) => x.id == selectedPatientId).toList();
        if (m.isNotEmpty) selectedPatientName = m.first.name;
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Sync from route whenever route changes (mobile/web)
  // ---------------------------------------------------------------------------

  void _recreateTabControllerIfNeeded(int newLen, int desiredIndex) {
    if (tabController.length == newLen) {
      if (desiredIndex != tabController.index) {
        tabController.index = desiredIndex;
      }
      return;
    }

    final old = tabController;
    tabController = TabController(
      length: newLen,
      initialIndex: desiredIndex.clamp(0, newLen - 1),
      vsync: this,
    );
    old.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newRole = _readRoleFromStateOrFallback();

    // Determine paths based on NEW role
    final pathsForNewRole =
        (newRole == "doctor") ? _doctorRecordTabPaths : _patientRecordTabPaths;

    final newTabIndex = _tabIndexFromStatePath(pathsForNewRole);

    final newApptId = _readAppointmentIdFromState();
    final newPid = _readPatientIdFromState();

    // only apply patientId from URL for doctor
    final pidForDoctor = (newRole == "doctor") ? newPid : null;

    final bool needsSetState =
        !_initializedFromRoute ||
        effectiveRole != newRole ||
        selectedAppointmentId != newApptId ||
        selectedPatientId != pidForDoctor;

    // If doctor tries to open /app/record/files, redirect to /app/record (orders)
    final currentPath = _state().uri.path;
    final isFilesPath = currentPath == "/app/record/files";
    if (newRole == "doctor" && isFilesPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // keep same query parameters but go to /app/record
        context.go(_buildRecordLocationForTab(tabOrders));
      });
    }

    _initializedFromRoute = true;

    effectiveRole = newRole;
    selectedAppointmentId = newApptId;

    if (effectiveRole == "doctor") {
      selectedPatientId = pidForDoctor;
      if (selectedPatientId != null) {
        selectedPatientName = null;
      }
      if (!loadingPatients && patientOptions.isEmpty) {
        loadingPatients = true;
        patientsErrorMessage = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            loadingPatients = true;
            patientsErrorMessage = null;
          });
          _loadDoctorPatientsFromOrders();
        });
      }
    } else {
      selectedPatientId = null;
      selectedPatientName = null;
    }

    // Ensure controller length matches role tabs
    _recreateTabControllerIfNeeded(pathsForNewRole.length, newTabIndex);

    if (!needsSetState) return;
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // UI blocks
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
    final doctorLabel =
        currentUserName.isNotEmpty ? "د. $currentUserName" : "د. -";

    // Doctor must select patient first if not provided in route.
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
                      message: "يتم تحميل قائمة المرضى المرتبطين بمواعيدك",
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
                          "يمكنك فتح الإضبارة من الموعد (سيتم تمرير patientId).",
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
            : (selectedPatientName?.trim().isNotEmpty ?? false)
            ? "الطبيب: $doctorLabel | المريض: ${selectedPatientName!.trim()}"
            : "الطبيب: $doctorLabel";

    final apptId = selectedAppointmentId;
    final hasAppt = apptId != null && apptId > 0;
    final apptKey = (selectedAppointmentId ?? 0);

    // قاعدة موحدة للخطوة القادمة:
    // الطبيب لا يستطيع الإنشاء إلا ضمن سياق موعد
    //final bool doctorCanCreate = !isDoctor || hasAppt;

    return Column(
      children: [
        _headerTile(titleText: subtitleText),

        if (hasAppt)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
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
          tabs:
              isDoctor
                  ? const [
                    Tab(text: "الطلبات"),
                    Tab(text: "الوصفات"),
                    Tab(text: "الالتزام"),
                    Tab(text: "البيانات"),
                  ]
                  : const [
                    Tab(text: "الطلبات"),
                    Tab(text: "رفع الملفات"),
                    Tab(text: "الوصفات"),
                    Tab(text: "الالتزام"),
                    Tab(text: "البيانات"),
                  ],
        ),

        Expanded(
          child: TabBarView(
            controller: tabController,
            children:
                isDoctor
                    ? [
                      OrdersTab(
                        key: ValueKey<String>(
                          "orders-$patientContextId-$apptKey",
                        ),
                        role: effectiveRole,
                        userId: widget.userId,
                        selectedPatientId: patientContextId,
                        selectedAppointmentId: selectedAppointmentId,
                        // ملاحظة: سنستخدم doctorCanCreate داخل OrdersTab لاحقًا لإخفاء زر الإنشاء
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
                        key: ValueKey<String>(
                          "health-profile-$patientContextId",
                        ),
                        role: effectiveRole,
                        userId: widget.userId,
                        selectedPatientId: patientContextId,
                      ),
                    ]
                    : [
                      OrdersTab(
                        key: ValueKey<String>(
                          "orders-$patientContextId-$apptKey",
                        ),
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
                        key: ValueKey<String>(
                          "health-profile-$patientContextId",
                        ),
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
