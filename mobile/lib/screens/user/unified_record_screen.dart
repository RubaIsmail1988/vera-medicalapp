import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/auth_service.dart';
import '/services/clinical_service.dart';

import 'clinical/orders_tab.dart';
import 'clinical/files_tab.dart';
import 'clinical/prescriptions_tab.dart';
import 'clinical/adherence_tab.dart';

class UnifiedRecordScreen extends StatefulWidget {
  final String role; // doctor | patient
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
  late final TabController tabController;
  late final ClinicalService clinicalService;

  // Header (from SharedPreferences)
  String currentUserName = "";

  // Doctor selection
  int? selectedPatientId;
  String? selectedPatientName;

  bool loadingPatients = false;
  List<_PatientOption> patientOptions = [];

  bool get isDoctor => widget.role == "doctor";
  bool get isPatient => widget.role == "patient";

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
    clinicalService = ClinicalService(authService: AuthService());

    _loadCurrentUserNameFromPrefs();

    if (isDoctor) {
      _loadDoctorPatientsFromOrders();
    }
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  String get roleLabel {
    if (widget.role == "doctor") return "طبيب";
    if (widget.role == "patient") return "مريض";
    return widget.role;
  }

  Future<void> _loadCurrentUserNameFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = (prefs.getString("currentUserName") ?? "").trim();

    if (!mounted) return;

    setState(() {
      currentUserName = name;
    });
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Future<void> _loadDoctorPatientsFromOrders() async {
    setState(() {
      loadingPatients = true;
      patientOptions = [];
      selectedPatientId = null;
      selectedPatientName = null;
    });

    final res = await clinicalService.listOrders();

    if (!mounted) return;

    if (res.statusCode != 200) {
      setState(() {
        loadingPatients = false;
      });
      return;
    }

    final decoded = jsonDecode(res.body);
    final List<Map<String, dynamic>> list =
        decoded is List
            ? decoded.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

    // Build unique patients from orders: patient(id) + patient_display_name(label)
    final Map<int, String> byId = {};

    for (final o in list) {
      final pid = _asInt(o["patient"]);
      if (pid == null || pid <= 0) continue;

      final name = (o["patient_display_name"]?.toString() ?? "").trim();
      if (name.isNotEmpty) {
        byId[pid] = name;
      } else {
        // fallback label without showing ID
        byId.putIfAbsent(pid, () => "مريض");
      }
    }

    final options =
        byId.entries
            .map((e) => _PatientOption(id: e.key, name: e.value))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      patientOptions = options;
      loadingPatients = false;

      // Optional: auto-select first patient to reduce steps (if you prefer)
      // if (patientOptions.isNotEmpty) {
      //   selectedPatientId = patientOptions.first.id;
      //   selectedPatientName = patientOptions.first.name;
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------
    // Doctor must select patient first
    // ------------------------------------------------------------
    if (isDoctor && selectedPatientId == null) {
      return Column(
        children: [
          Material(
            child: ListTile(
              leading: const Icon(Icons.folder_shared),
              title: const Text("الإضبارة الطبية الموحدة"),
              subtitle: Text(
                "الدور: $roleLabel | الطبيب: ${currentUserName.isNotEmpty ? "د. $currentUserName" : "د. -"}",
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("اختر مريضًا لعرض الإضبارة"),
          const SizedBox(height: 16),

          if (loadingPatients)
            const CircularProgressIndicator()
          else if (patientOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("لا يوجد مرضى متاحون."),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "اختر مريضًا",
                  border: OutlineInputBorder(),
                ),
                items:
                    patientOptions
                        .map(
                          (p) => DropdownMenuItem<int>(
                            value: p.id,
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final picked =
                      patientOptions.where((x) => x.id == v).toList();
                  final name = picked.isNotEmpty ? picked.first.name : "مريض";

                  setState(() {
                    selectedPatientId = v;
                    selectedPatientName = name;
                  });
                },
              ),
            ),
        ],
      );
    }

    final int? patientContextId = isDoctor ? selectedPatientId : widget.userId;

    // Header subtitle per final policy:
    // - patient: show patient name only (no ID)
    // - doctor: show doctor name + chosen patient name (no ID)
    final subtitleText =
        isPatient
            ? "المريض: ${currentUserName.isNotEmpty ? currentUserName : "-"}"
            : "الطبيب: ${currentUserName.isNotEmpty ? "د. $currentUserName" : "د. -"}"
                " | المريض: ${(selectedPatientName?.trim().isNotEmpty ?? false) ? selectedPatientName!.trim() : "-"}";

    return Column(
      children: [
        Material(
          child: ListTile(
            leading: const Icon(Icons.folder_shared),
            title: const Text("الإضبارة الطبية الموحدة"),
            subtitle: Text(subtitleText),
          ),
        ),
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Orders"),
            Tab(text: "Files"),
            Tab(text: "Prescriptions"),
            Tab(text: "Adherence"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              OrdersTab(
                key: ValueKey<String>("orders-$patientContextId"),
                role: widget.role,
                userId: widget.userId,
                selectedPatientId: patientContextId,
              ),
              FilesTab(
                key: ValueKey<String>("files-$patientContextId"),
                role: widget.role,
                userId: widget.userId,
                selectedPatientId: patientContextId,
              ),
              PrescriptionsTab(
                key: ValueKey<String>("prescriptions-$patientContextId"),
                role: widget.role,
                userId: widget.userId,
                selectedPatientId: patientContextId,
              ),
              AdherenceTab(
                key: ValueKey<String>("adherence-$patientContextId"),
                role: widget.role,
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
