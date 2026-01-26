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

    try {
      final result = await service.requestOtp(email: email);

      if (!mounted) return;
      setState(() => loading = false);

      if (!result.success) {
        showActionErrorSnackBar(
          context,
          fallback: 'تعذّر إرسال الرمز. تحقق من الاتصال ثم حاول مرة أخرى.',
        );
        return;
      }

      // حالة PythonAnywhere المجاني: OTP يرجع في response
      if (result.delivery == 'disabled' && (result.otp ?? '').isNotEmpty) {
        final otp = result.otp!;
        final expires = result.expiresInMinutes ?? 10;

        // لا تستخدم context بعد await إلا مع mounted
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('رمز التحقق (بيئة تجريبية)'),
                content: Text('الرمز: $otp\nصالح لمدة $expires دقائق.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('متابعة'),
                  ),
                ],
              ),
            );
          },
        );

        if (!mounted) return;

        showAppSnackBar(
          context,
          'تم إنشاء رمز التحقق. انتقل الآن لصفحة إدخال الرمز.',
          type: AppSnackBarType.success,
        );

        final encodedEmail = Uri.encodeComponent(email);
        context.go('/forgot-password/verify?email=$encodedEmail');
        return;
      }

      // الوضع الطبيعي: email
      showAppSnackBar(
        context,
        'إذا كان البريد صحيحًا، سيصلك رمز التحقق خلال لحظات.',
        type: AppSnackBarType.success,
      );

      final encodedEmail = Uri.encodeComponent(email);
      context.go('/forgot-password/verify?email=$encodedEmail');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر إرسال الرمز. تحقق من الاتصال ثم حاول مرة أخرى.',
      );
    }
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
                            onFieldSubmitted: (_) {
                              if (!loading) submit();
                            },
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
