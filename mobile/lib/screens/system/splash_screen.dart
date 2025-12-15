import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/app_logo.dart';
import '../auth/login_screen.dart';
import '../admin/admin_shell_screen.dart';
import '../user/user_shell_screen.dart';
// import '../pin/enter_pin_screen.dart'; // ← سيُفعل لاحقًا

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    // مدة قصيرة ليظهر اللوغو بشكل لطيف
    await Future.delayed(const Duration(milliseconds: 700));

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final role = prefs.getString('user_role');
    final userId = prefs.getInt('user_id');

    if (!mounted) return;

    // --------------------------------------------------
    // 1) لا يوجد تسجيل دخول
    // --------------------------------------------------
    if (token == null || token.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (role == null || userId == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // --------------------------------------------------
    //  مرحلة PIN (مؤجلة)
    // عند التفعيل فقط:
    //
    // final hasPin = prefs.getBool('has_pin') == true;
    // if (hasPin) {
    //   Navigator.pushReplacement(
    //     context,
    //     MaterialPageRoute(builder: (_) => const EnterPinScreen()),
    //   );
    //   return;
    // }
    // --------------------------------------------------

    // --------------------------------------------------
    // 2) توجيه حسب الدور
    // --------------------------------------------------
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminShellScreen()),
      );
      return;
    }

    if (role == 'patient' || role == 'doctor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => UserShellScreen(role: role, userId: userId, token: token),
        ),
      );
      return;
    }

    // --------------------------------------------------
    // 3) حالة احتياطية
    // --------------------------------------------------
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(width: 220),
              const SizedBox(height: 24),
              Text(
                'Vera Smart Health',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
