import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '/screens/user/edit_doctor_details_screen.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final int userId;
  final String token;

  const DoctorDetailsScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  Map<String, dynamic>? details;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  Future<void> fetchDetails() async {
    final url = Uri.parse(
      "http://127.0.0.1:8000/api/accounts/doctor-details/${widget.userId}/",
    );

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
          details = jsonDecode(response.body);
          loading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = "Failed to load details: ${response.body}";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("تفاصيل الطبيب"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child:
            loading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: cs.onSurface),
                  ),
                )
                : details == null
                ? Center(
                  child: Text(
                    "لا توجد بيانات",
                    style: TextStyle(color: cs.onSurface),
                  ),
                )
                : ListView(
                  children: [
                    _infoTile(
                      context: context,
                      title: "التخصص",
                      value: details!["specialty"]?.toString() ?? "-",
                    ),
                    _infoTile(
                      context: context,
                      title: "سنوات الخبرة",
                      value: "${details!["experience_years"] ?? 0} سنة",
                    ),
                    _infoTile(
                      context: context,
                      title: "ملاحظات",
                      value:
                          details!["notes"]?.toString().isNotEmpty == true
                              ? details!["notes"].toString()
                              : "لا يوجد",
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('رجوع'),
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
                                (_) => EditDoctorDetailsScreen(
                                  token: widget.token,
                                  userId: widget.userId,
                                  specialty:
                                      details!["specialty"]?.toString() ?? "",
                                  experienceYears: _parseExperience(
                                    details!["experience_years"],
                                  ),
                                  notes: details!["notes"]?.toString(),
                                ),
                          ),
                        );

                        if (!mounted) return;

                        if (updated == true) {
                          setState(() {
                            loading = true;
                          });
                          await fetchDetails();
                        }
                      },
                    ),
                  ],
                ),
      ),
    );
  }

  int _parseExperience(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  Widget _infoTile({
    required BuildContext context,
    required String title,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;

    // Material 3: surfaceContainerHighest يعطي بطاقة جميلة في light/dark
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
