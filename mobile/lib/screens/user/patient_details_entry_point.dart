import 'package:flutter/material.dart';

import '/services/details_service.dart';
import 'patient_details_form_screen.dart';
import 'patient_details_screen.dart';

class PatientDetailsEntryPoint extends StatefulWidget {
  final String token;
  final int userId;

  const PatientDetailsEntryPoint({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<PatientDetailsEntryPoint> createState() =>
      _PatientDetailsEntryPointState();
}

class _PatientDetailsEntryPointState extends State<PatientDetailsEntryPoint> {
  bool loading = true;
  bool hasDetails = false;

  @override
  void initState() {
    super.initState();
    checkPatientDetails();
  }

  Future<void> checkPatientDetails() async {
    try {
      final response = await DetailsService().getPatientDetails(widget.userId);

      if (response.statusCode == 200) {
        // يوجد تفاصيل
        setState(() {
          hasDetails = true;
          loading = false;
        });
      } else if (response.statusCode == 404) {
        // لا يوجد تفاصيل
        setState(() {
          hasDetails = false;
          loading = false;
        });
      } else {
        // أي حالة أخرى نعتبرها "لا يوجد تفاصيل" مع رسالة لوج فقط
        setState(() {
          hasDetails = false;
          loading = false;
        });
      }
    } catch (e) {
      // خطأ بالشبكة أو غيره
      setState(() {
        hasDetails = false;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // إذا لا يوجد بيانات : نذهب إلى شاشة إدخال التفاصيل الحقيقية
    if (!hasDetails) {
      return PatientDetailsFormScreen(
        token: widget.token,
        userId: widget.userId,
      );
    }

    // إذا يوجد بيانات : نعرض شاشة تفاصيل المريض الحقيقية
    return PatientDetailsScreen(token: widget.token, userId: widget.userId);
  }
}
