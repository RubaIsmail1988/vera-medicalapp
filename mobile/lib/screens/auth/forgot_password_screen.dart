import 'package:flutter/material.dart';
import '/services/password_reset_service.dart';
import 'reset_password_verify_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();

  bool loading = false;

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final email = emailController.text.trim().toLowerCase();
    final service = PasswordResetService();

    final ok = await service.requestOtp(email: email);

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (!ok) {
      showSnackBar('تعذّر إرسال الرمز. حاول مرة أخرى.');
      return;
    }

    // ملاحظة أمنية: حتى لو البريد غير موجود، نتابع بنفس الرسالة
    showSnackBar('إذا كان البريد صحيحًا، سيصلك رمز التحقق خلال لحظات.');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResetPasswordVerifyOtpScreen(email: email),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Icon(Icons.lock_reset, size: 72, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'أدخل بريدك الإلكتروني لإرسال رمز التحقق (OTP).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'هذا الحقل مطلوب';
                    if (!text.contains('@') || !text.contains('.')) {
                      return 'صيغة بريد غير صحيحة';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : submit,
                    child:
                        loading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('إرسال الرمز'),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(context),
                  child: const Text('العودة لتسجيل الدخول'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
