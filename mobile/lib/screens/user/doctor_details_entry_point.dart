import 'package:flutter/material.dart';

import '/services/details_service.dart';
import 'doctor_details_form_screen.dart';
import 'doctor_details_screen.dart';

class DoctorDetailsEntryPoint extends StatefulWidget {
  final String token;
  final int userId;

  const DoctorDetailsEntryPoint({
    super.key,
    required this.token,
    required this.userId,
  });

  @override
  State<DoctorDetailsEntryPoint> createState() =>
      _DoctorDetailsEntryPointState();
}

class _DoctorDetailsEntryPointState extends State<DoctorDetailsEntryPoint> {
  bool loading = true;
  bool hasDetails = false;

  @override
  void initState() {
    super.initState();
    checkDoctorDetails();
  }

  Future<void> checkDoctorDetails() async {
    try {
      final response = await DetailsService().getDoctorDetails(widget.userId);

      if (!mounted) return;

      if (response.statusCode == 200) {
        // يوجد تفاصيل للطبيب
        setState(() {
          hasDetails = true;
          loading = false;
        });
      } else if (response.statusCode == 404) {
        // لا يوجد تفاصيل للطبيب
        setState(() {
          hasDetails = false;
          loading = false;
        });
      } else {
        // أي حالة أخرى نعتبرها "لا يوجد تفاصيل" مؤقتاً
        setState(() {
          hasDetails = false;
          loading = false;
        });
        // يمكن إضافة print هنا إذا أحببتِ:
        // print('Unexpected status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasDetails = false;
        loading = false;
      });
      // يمكن إضافة print للـ error هنا أيضاً
      // print('Error while checking doctor details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // لا يوجد تفاصيل → نعرض فورم إدخال تفاصيل الطبيب
    if (!hasDetails) {
      return DoctorDetailsFormScreen(
        token: widget.token,
        userId: widget.userId,
      );
    }

    // يوجد تفاصيل → نعرض شاشة تفاصيل الطبيب
    return DoctorDetailsScreen(token: widget.token, userId: widget.userId);
  }
}
