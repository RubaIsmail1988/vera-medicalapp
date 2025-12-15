import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '/screens/user/edit_patient_details_screen.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String token;
  final int userId;

  const PatientDetailsScreen({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen> {
  bool loading = true;
  Map<String, dynamic>? patientData;

  @override
  void initState() {
    super.initState();
    fetchPatientDetails();
  }

  Future<void> fetchPatientDetails() async {
    final url = Uri.parse(
      "http://127.0.0.1:8000/api/accounts/patient-details/${widget.userId}/",
    );

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
        patientData = jsonDecode(response.body);
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });

      // ملاحظة: لاحقًا يمكننا توحيد showSnackBar في util (حسب checklist)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تعذّر تحميل بيانات المريض")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل المريض"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : patientData == null
              ? Center(
                child: Text(
                  "لا توجد بيانات",
                  style: TextStyle(color: cs.onSurface),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    infoTile(
                      context: context,
                      title: "تاريخ الميلاد",
                      value: patientData!["date_of_birth"] ?? "-",
                    ),
                    infoTile(
                      context: context,
                      title: "الطول",
                      value: "${patientData!["height"] ?? "-"} سم",
                    ),
                    infoTile(
                      context: context,
                      title: "الوزن",
                      value: "${patientData!["weight"] ?? "-"} كغ",
                    ),
                    infoTile(
                      context: context,
                      title: "BMI",
                      value: patientData!["bmi"]?.toString() ?? "-",
                    ),
                    infoTile(
                      context: context,
                      title: "ملاحظات صحية",
                      value: patientData!["health_notes"] ?? "لا يوجد",
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("رجوع"),
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton.icon(
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
                                  dateOfBirth: patientData!["date_of_birth"],
                                  height:
                                      patientData!["height"] != null
                                          ? double.tryParse(
                                            patientData!["height"].toString(),
                                          )
                                          : null,
                                  weight:
                                      patientData!["weight"] != null
                                          ? double.tryParse(
                                            patientData!["weight"].toString(),
                                          )
                                          : null,
                                  bmi:
                                      patientData!["bmi"] != null
                                          ? double.tryParse(
                                            patientData!["bmi"].toString(),
                                          )
                                          : null,
                                  healthNotes: patientData!["health_notes"],
                                ),
                          ),
                        );

                        if (!mounted) return;

                        if (updated == true) {
                          setState(() {
                            loading = true;
                          });
                          await fetchPatientDetails();
                        }
                      },
                    ),
                  ],
                ),
              ),
    );
  }

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

    return Container(
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
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: valueColor),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
