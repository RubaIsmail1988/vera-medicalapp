import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/password_reset_service.dart';
import '/utils/ui_helpers.dart';

class ResetPasswordVerifyOtpScreen extends StatefulWidget {
  final String email;

  const ResetPasswordVerifyOtpScreen({super.key, required this.email});

  @override
  State<ResetPasswordVerifyOtpScreen> createState() =>
      _ResetPasswordVerifyOtpScreenState();
}

class _ResetPasswordVerifyOtpScreenState
    extends State<ResetPasswordVerifyOtpScreen> {
  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();

  bool loading = false;

  String? codeValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'رمز التحقق مطلوب';
    if (text.length != 6) return 'الرمز يجب أن يكون 6 أرقام';
    if (int.tryParse(text) == null) return 'الرجاء إدخال أرقام فقط';
    return null;
  }

  Future<void> verify() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final code = codeController.text.trim();
    final service = PasswordResetService();

    try {
      final valid = await service.verifyOtp(email: widget.email, code: code);

      if (!mounted) return;
      setState(() => loading = false);

      if (!valid) {
        showActionErrorSnackBar(
          context,
          fallback: 'رمز غير صحيح أو منتهي الصلاحية.',
        );
        return;
      }

      final encodedEmail = Uri.encodeComponent(widget.email);
      final encodedCode = Uri.encodeComponent(code);
      context.go('/forgot-password/new?email=$encodedEmail&code=$encodedCode');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر التحقق من الرمز. تحقق من الاتصال ثم حاول مرة أخرى.',
      );
    }
  }

  void goBackToEmail() {
    // لا يوجد await هنا، فمسموح استخدام context مباشرة
    context.go('/forgot-password');
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحقق من الرمز'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: loading ? null : goBackToEmail,
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: formKey,
              child: Column(
                children: [
                  Icon(Icons.verified_outlined, size: 72, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'رمز التحقق',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني:',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: codeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'رمز OTP (6 أرقام)',
                            ),
                            maxLength: 6,
                            validator: codeValidator,
                            enabled: !loading,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!loading) verify();
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: loading ? null : verify,
                              child:
                                  loading
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('تحقق'),
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
