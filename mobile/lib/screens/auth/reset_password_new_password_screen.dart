import 'package:flutter/material.dart';
import '/services/password_reset_service.dart';

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

    final service = PasswordResetService();

    final success = await service.confirmNewPassword(
      email: widget.email,
      code: widget.code,
      newPassword: passwordController.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (!success) {
      showSnackBar('فشل تغيير كلمة المرور. تحققي من الرمز وحاولي مجددًا.');
      return;
    }

    showSnackBar('تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.');

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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
      appBar: AppBar(title: const Text('كلمة مرور جديدة')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Icon(Icons.password_outlined, size: 72, color: cs.primary),
                const SizedBox(height: 16),

                // كلمة المرور الجديدة
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
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
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'هذا الحقل مطلوب';
                    if (text.length < 6) {
                      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // تأكيد كلمة المرور
                TextFormField(
                  controller: confirmController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور',
                    suffixIcon: IconButton(
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
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'هذا الحقل مطلوب';
                    if (text != passwordController.text.trim()) {
                      return 'كلمتا المرور غير متطابقتين';
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
                            : const Text('حفظ كلمة المرور'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
