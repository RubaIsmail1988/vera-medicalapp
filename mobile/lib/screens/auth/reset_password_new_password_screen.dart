import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/password_reset_service.dart';
import '/utils/ui_helpers.dart';

class ResetPasswordNewPasswordScreen extends StatefulWidget {
  final String email;
  final String code;

  const ResetPasswordNewPasswordScreen({
    super.key,
    required this.email,
    required this.code,
  });

  @override
  State<ResetPasswordNewPasswordScreen> createState() =>
      _ResetPasswordNewPasswordScreenState();
}

class _ResetPasswordNewPasswordScreenState
    extends State<ResetPasswordNewPasswordScreen> {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  String? passwordValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'كلمة المرور الجديدة مطلوبة';
    if (text.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    return null;
  }

  String? confirmValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'تأكيد كلمة المرور مطلوب';
    if (text != passwordController.text.trim()) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  void goBackToVerify() {
    final encodedEmail = Uri.encodeComponent(widget.email);
    context.go('/forgot-password/verify?email=$encodedEmail');
  }

  Future<void> submit() async {
    if (loading) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    final service = PasswordResetService();
    final newPassword = passwordController.text.trim();

    try {
      final success = await service.confirmNewPassword(
        email: widget.email,
        code: widget.code,
        newPassword: newPassword,
      );

      if (!mounted) return;
      setState(() => loading = false);

      if (!success) {
        showActionErrorSnackBar(
          context,
          fallback: 'فشل تغيير كلمة المرور. تحقق من الرمز وحاول مجدداً.',
        );
        return;
      }

      showAppSnackBar(
        context,
        'تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.',
        type: AppSnackBarType.success,
      );

      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر تغيير كلمة المرور. تحقق من الاتصال ثم حاول مرة أخرى.',
      );
    }
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('كلمة مرور جديدة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: loading ? null : goBackToVerify,
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
                  Icon(Icons.password_outlined, size: 72, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'تعيين كلمة مرور جديدة',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر كلمة مرور قوية ثم أكدها.',
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
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور الجديدة',
                              suffixIcon: IconButton(
                                tooltip: obscurePassword ? 'إظهار' : 'إخفاء',
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
                            validator: passwordValidator,
                            enabled: !loading,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: confirmController,
                            obscureText: obscureConfirm,
                            decoration: InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              suffixIcon: IconButton(
                                tooltip: obscureConfirm ? 'إظهار' : 'إخفاء',
                                icon: Icon(
                                  obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureConfirm = !obscureConfirm;
                                  });
                                },
                              ),
                            ),
                            validator: confirmValidator,
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
                                      : const Text('حفظ كلمة المرور'),
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
