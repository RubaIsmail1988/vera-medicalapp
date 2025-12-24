import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '/utils/constants.dart';
import '/utils/ui_helpers.dart';

import 'doctor_details_form_screen.dart';
import 'edit_doctor_details_screen.dart';

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
  bool notFound = false; // 404: لا يوجد تفاصيل
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchDetails();
  }

  void _goBackSafe() {
    if (!mounted) return;

    if (context.canPop()) {
      context.pop();
      return;
    }

    // في حال فتح الصفحة مباشرة عبر URL (no stack)
    context.go('/app/account');
  }

  Future<void> fetchDetails() async {
    if (mounted) {
      setState(() {
        loading = true;
        notFound = false;
        errorMessage = null;
        details = null;
      });
    }

    final url = Uri.parse("$accountsBaseUrl/doctor-details/${widget.userId}/");

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
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
        errorMessage = "فشل تحميل التفاصيل (Code: ${response.statusCode})";
      });

      showAppSnackBar(
        context,
        'تعذّر تحميل تفاصيل الطبيب.',
        type: AppSnackBarType.error,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = "خطأ اتصال: $e";
      });

      showAppSnackBar(
        context,
        'تعذّر الاتصال بالخادم. حاول لاحقاً.',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> openCreateForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DoctorDetailsFormScreen(
              token: widget.token,
              userId: widget.userId,
            ),
      ),
    );

    if (!mounted) return;
    await fetchDetails();
  }

  int _parseExperience(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 404: لا يوجد بيانات
    if (notFound) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطبيب'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackSafe,
          ),
        ),
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
                    'لا توجد بيانات مهنية محفوظة لهذا الطبيب.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'يمكنك إضافة تفاصيل الطبيب الآن.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: openCreateForm,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة البيانات'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _goBackSafe, child: const Text('رجوع')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // خطأ آخر
    if (details == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل الطبيب'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackSafe,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 72, color: cs.error),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage ?? 'حدث خطأ غير معروف.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: fetchDetails,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _goBackSafe, child: const Text('رجوع')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // يوجد بيانات
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطبيب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackSafe,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            infoTile(
              context: context,
              title: 'التخصص',
              value: details!['specialty']?.toString() ?? '-',
            ),
            infoTile(
              context: context,
              title: 'سنوات الخبرة',
              value: '${details!['experience_years'] ?? 0} سنة',
            ),
            infoTile(
              context: context,
              title: 'ملاحظات',
              value:
                  (details!['notes']?.toString().trim().isNotEmpty == true)
                      ? details!['notes'].toString()
                      : 'لا يوجد',
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('تعديل البيانات'),
                onPressed: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => EditDoctorDetailsScreen(
                            token: widget.token,
                            userId: widget.userId,
                            specialty: details!['specialty']?.toString() ?? '',
                            experienceYears: _parseExperience(
                              details!['experience_years'],
                            ),
                            notes: details!['notes']?.toString(),
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
              child: ElevatedButton(
                onPressed: _goBackSafe,
                child: const Text('رجوع'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
