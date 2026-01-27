import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/app_logo.dart';

// Services
import '../../services/appointments_service.dart';
import '../../services/local_notifications_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // ignore: unawaited_futures
    start();
  }

  Future<void> start() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final token = (prefs.getString('access_token') ?? '').trim();
      final role = (prefs.getString('user_role') ?? '').trim();
      final userId = prefs.getInt('user_id') ?? 0;

      // مهم لتوحيد سلوك الطبيب غير المفعّل
      final bool? isActive = prefs.getBool('user_is_active');

      // 1) لا يوجد تسجيل دخول
      if (token.isEmpty || role.isEmpty || userId == 0) {
        context.go('/login');
        return;
      }

      // ✅ ثبّت role داخل LocalNotificationsService (بدون await)
      LocalNotificationsService.setCurrentRole(role);

      // ✅ Sync للتذكيرات عند فتح التطبيق (بدون انتظار)
      // ملاحظة: نعتمد سياسة confirmed فقط داخل AppointmentsService
      // ignore: unawaited_futures
      AppointmentsService().syncMyRemindersNow();

      // 2) توجيه حسب الدور
      if (role == 'admin') {
        context.go('/admin');
        return;
      }

      if (role == 'doctor') {
        // إذا الطبيب غير مفعّل → شاشة انتظار التفعيل
        if (isActive == false) {
          context.go('/waiting-activation');
          return;
        }
        context.go('/app');
        return;
      }

      if (role == 'patient') {
        context.go('/app');
        return;
      }

      // 3) احتياطي
      context.go('/login');
    } catch (_) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLogo(width: 220),
                    const SizedBox(height: 20),
                    Text(
                      'Vera Smart Health',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
