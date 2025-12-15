import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';
import '../user/user_shell_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final AuthService authService = AuthService();

  bool loading = false;
  bool obscurePassword = true;

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> login() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final result = await authService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (result == null) {
      showSnackBar('البريد الإلكتروني أو كلمة المرور غير صحيحة');
      return;
    }

    final Map<String, dynamic> data = result;

    if (data['error'] == 'not_active') {
      Navigator.pushReplacementNamed(context, '/waiting-activation');
      return;
    }

    final String role = data['role']?.toString() ?? '';
    final bool isActive = data['is_active'] == true;

    final dynamic rawUserId = data['user_id'];
    final int userId =
        rawUserId is int
            ? rawUserId
            : int.tryParse(rawUserId?.toString() ?? '') ?? 0;

    final String accessToken = data['access_token']?.toString() ?? '';

    if (!isActive) {
      Navigator.pushReplacementNamed(context, '/waiting-activation');
      return;
    }

    if (accessToken.isEmpty || userId == 0 || role.isEmpty) {
      showSnackBar('الاستجابة من الخادم غير مكتملة، حاول مرة أخرى');
      return;
    }

    await authService.fetchAndStoreCurrentUser();

    if (!mounted) return;

    if (role == 'patient' || role == 'doctor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => UserShellScreen(
                role: role,
                userId: userId,
                token: accessToken,
              ),
        ),
      );
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin-home');
    } else {
      showSnackBar('دور مستخدم غير معروف: $role');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(width: 220),
                const SizedBox(height: 24),

                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    final trimmed = value.trim();
                    if (!trimmed.contains('@') || !trimmed.contains('.')) {
                      return 'صيغة بريد غير صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: obscurePassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'هذا الحقل مطلوب';
                    }
                    if (value.length < 4) {
                      return 'كلمة المرور قصيرة جداً';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child:
                      loading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                            onPressed: login,
                            child: const Text('تسجيل الدخول'),
                          ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/forgot-password');
                  },
                  child: const Text('نسيت كلمة المرور؟'),
                ),
                const SizedBox(height: 12),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text('إنشاء حساب جديد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
