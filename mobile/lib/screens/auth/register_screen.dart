import 'package:flutter/material.dart';

import '/services/auth_service.dart';
import '/models/register_request.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final formKey = GlobalKey<FormState>();
  final authService = AuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController governorateController = TextEditingController();

  String role = 'patient';

  bool loading = false;
  bool obscurePassword = true;

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }

    final trimmed = value.trim();
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }

    return null;
  }

  String? usernameValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم المستخدم مطلوب';
    }
    if (value.trim().length < 3) {
      return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
    }
    return null;
  }

  String? passwordValidator(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }
    if (value.length < 8) {
      return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    }
    return null;
  }

  String? phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم الجوال مطلوب';
    }
    final trimmed = value.trim();
    final phoneRegex = RegExp(r'^[0-9+\-\s]+$');
    if (!phoneRegex.hasMatch(trimmed)) {
      return 'صيغة رقم الجوال غير صحيحة';
    }
    return null;
  }

  String? governorateValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'رقم المحافظة مطلوب';
    }
    final trimmed = value.trim();
    if (int.tryParse(trimmed) == null) {
      return 'رقم المحافظة يجب أن يكون رقمًا صحيحًا';
    }
    return null;
  }

  String? addressValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'العنوان مطلوب';
    }
    if (value.trim().length < 5) {
      return 'الرجاء إدخال عنوان أوضح';
    }
    return null;
  }

  Future<void> register() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final request = RegisterRequest(
      email: emailController.text.trim(),
      username: usernameController.text.trim(),
      password: passwordController.text.trim(),
      phone: phoneController.text.trim(),
      governorate: int.parse(governorateController.text.trim()),
      address: addressController.text.trim(),
      role: role,
    );

    try {
      final response = await authService.register(request);

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      if (response.statusCode == 201) {
        // =========================
        // منطق ما بعد التسجيل حسب الدور
        // =========================
        final email = emailController.text.trim();

        if (role == 'patient') {
          // مريض: رسالة نجاح قصيرة → إعادة توجيه إلى Login + تمرير البريد
          showSnackBar('تم إنشاء حساب المريض بنجاح. يمكنك الآن تسجيل الدخول.');
          Navigator.pushReplacementNamed(
            context,
            '/login',
            arguments: {'email': email},
          );
        } else if (role == 'doctor') {
          // طبيب: الحساب قيد التفعيل → إعادة توجيه إلى WaitingActivationScreen
          showSnackBar('تم إرسال طلب التسجيل. حساب الطبيب قيد التفعيل.');
          Navigator.pushReplacementNamed(context, '/waiting-activation');
        } else {
          // احتياط لأي دور آخر مستقبلاً
          showSnackBar('تم إنشاء الحساب بنجاح.');
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        // نعرض رسالة خطأ موحّدة مع محتوى مختصر من الـ body
        final bodyText = response.body.toString();
        if (bodyText.isEmpty) {
          showSnackBar('حدث خطأ أثناء التسجيل. حاول مرة أخرى.');
        } else {
          showSnackBar('خطأ أثناء التسجيل: $bodyText');
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showSnackBar('حدث خطأ غير متوقع أثناء التسجيل: $e');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    addressController.dispose();
    governorateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                // البريد الإلكتروني
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: emailValidator,
                ),
                const SizedBox(height: 16),

                // اسم المستخدم
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    border: OutlineInputBorder(),
                  ),
                  validator: usernameValidator,
                ),
                const SizedBox(height: 16),

                // كلمة المرور
                TextFormField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: const OutlineInputBorder(),
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
                  validator: passwordValidator,
                ),
                const SizedBox(height: 16),

                // رقم الجوال
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: phoneValidator,
                ),
                const SizedBox(height: 16),

                // رقم المحافظة
                TextFormField(
                  controller: governorateController,
                  decoration: const InputDecoration(
                    labelText: 'رقم المحافظة (ID)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: governorateValidator,
                ),
                const SizedBox(height: 16),

                // العنوان
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'العنوان',
                    border: OutlineInputBorder(),
                  ),
                  validator: addressValidator,
                ),
                const SizedBox(height: 16),

                // الدور (مريض / طبيب)
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'الدور',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'patient', child: Text('مريض')),
                    DropdownMenuItem(value: 'doctor', child: Text('طبيب')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      role = value;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // زر التسجيل مع حالة تحميل وتعطيل أثناء الإرسال
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : register,
                    child:
                        loading
                            ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text('جاري إنشاء الحساب...'),
                              ],
                            )
                            : const Text('تسجيل'),
                  ),
                ),

                const SizedBox(height: 12),

                // العودة إلى تسجيل الدخول
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('لديك حساب مسبقًا؟ تسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
