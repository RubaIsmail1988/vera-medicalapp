import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
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

      if (token.isEmpty || role.isEmpty || userId == 0) {
        context.go('/login');
        return;
      }

      // 1) Validate session BEFORE routing or syncing anything
      final auth = AuthService();
      final me = await auth.fetchAndStoreCurrentUser();
      if (!mounted) return;

      if (me == null) {
        await auth.logout();
        if (!mounted) return;
        context.go('/login');
        return;
      }

      // 2) Now it's safe to set role + do reminder sync
      final backendRole = (me["role"]?.toString() ?? role).trim();
      final isActive = prefs.getBool('user_is_active') ?? true;

      LocalNotificationsService.setCurrentRole(backendRole);

      // ignore: unawaited_futures
      AppointmentsService().syncMyRemindersNow();

      if (backendRole == 'admin') {
        context.go('/admin');
        return;
      }

      if (backendRole == 'doctor' && isActive == false) {
        context.go('/waiting-activation');
        return;
      }

      context.go('/app');
    } catch (e) {
      if (!mounted) return;
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogo(width: 220),
            SizedBox(height: 32),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
