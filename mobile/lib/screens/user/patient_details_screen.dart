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

      // أي status غير 200/404: نعتبره خطأ تحميل
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

    // 404: لا يوجد بيانات
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

    // خطأ تحميل (بدون عرض نص exception الخام)
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

    // يوجد بيانات
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text("تفاصيل المريض")),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              infoTile(
                context: context,
                title: "تاريخ الميلاد",
                value: details!["date_of_birth"]?.toString() ?? "-",
              ),
              infoTile(
                context: context,
                title: "الطول",
                value: "${details!["height"] ?? "-"} سم",
              ),
              infoTile(
                context: context,
                title: "الوزن",
                value: "${details!["weight"] ?? "-"} كغ",
              ),
              infoTile(
                context: context,
                title: "BMI",
                value: details!["bmi"]?.toString() ?? "-",
              ),
              infoTile(
                context: context,
                title: "أمراض مزمنة",
                value:
                    details!["chronic_disease"]?.toString().trim().isNotEmpty ==
                            true
                        ? details!["chronic_disease"].toString()
                        : "لا يوجد",
              ),
              infoTile(
                context: context,
                title: "ملاحظات صحية",
                value:
                    details!["health_notes"]?.toString().trim().isNotEmpty ==
                            true
                        ? details!["health_notes"].toString()
                        : "لا يوجد",
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

  void _goBack() {
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/app/account');
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
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
