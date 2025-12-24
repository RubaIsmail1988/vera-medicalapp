import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/password_reset_service.dart';
import '/utils/ui_helpers.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();

  bool loading = false;

  String normalizeEmail(String input) => input.trim().toLowerCase();

  String? emailValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'البريد الإلكتروني مطلوب';

    // تحقق بسيط وعملي للبريد
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(text)) return 'صيغة البريد الإلكتروني غير صحيحة';

    return null;
  }

  Future<void> submit() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final email = normalizeEmail(emailController.text);
    final service = PasswordResetService();

    bool ok = false;
    try {
      ok = await service.requestOtp(email: email);
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);

      showAppSnackBar(
        context,
        'تعذّر إرسال الرمز. تحقق من الاتصال ثم حاول مرة أخرى.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!mounted) return;
    setState(() => loading = false);

    if (!ok) {
      showAppSnackBar(
        context,
        'تعذّر إرسال الرمز. حاول مرة أخرى.',
        type: AppSnackBarType.error,
      );
      return;
    }

    showAppSnackBar(
      context,
      'إذا كان البريد صحيحًا، سيصلك رمز التحقق خلال لحظات.',
      type: AppSnackBarType.success,
    );

    final encodedEmail = Uri.encodeComponent(email);
    if (!mounted) return;
    context.go('/forgot-password/verify?email=$encodedEmail');
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Icon(Icons.lock_reset, size: 72, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'استعادة كلمة المرور',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أدخل بريدك الإلكتروني لإرسال رمز التحقق (OTP).',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                            ),
                            validator: emailValidator,
                            enabled: !loading,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => submit(),
                          ),
                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : submit,
                              child:
                                  loading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('إرسال الرمز'),
                            ),
                          ),
                          const SizedBox(height: 8),

                          TextButton(
                            onPressed:
                                loading ? null : () => context.go('/login'),
                            child: const Text('العودة لتسجيل الدخول'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
