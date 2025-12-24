import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    await Future.delayed(const Duration(milliseconds: 700));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final role = prefs.getString('user_role');
    final userId = prefs.getInt('user_id');

    if (!mounted) return;

    // 1) لا يوجد تسجيل دخول
    if (token == null || token.isEmpty) {
      context.go('/login');
      return;
    }

    if (role == null || userId == null) {
      context.go('/login');
      return;
    }

    // 2) توجيه حسب الدور
    if (role == 'admin') {
      context.go('/admin');
      return;
    }

    if (role == 'patient' || role == 'doctor') {
      context.go('/app');
      return;
    }

    // 3) احتياطي
    context.go('/login');
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
