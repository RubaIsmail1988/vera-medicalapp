import 'package:flutter/material.dart';
import '/services/password_reset_service.dart';
import 'reset_password_new_password_screen.dart';

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

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> verify() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
    });

    final code = codeController.text.trim();
    final service = PasswordResetService();

    final valid = await service.verifyOtp(email: widget.email, code: code);

    if (!mounted) return;

    setState(() {
      loading = false;
    });

    if (!valid) {
      showSnackBar('رمز غير صحيح أو منتهي الصلاحية.');
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                ResetPasswordNewPasswordScreen(email: widget.email, code: code),
      ),
    );
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
      appBar: AppBar(title: const Text('تحقق من الرمز')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                Icon(Icons.verified_outlined, size: 72, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'أدخل رمز التحقق المرسل إلى بريدك:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'رمز OTP (6 أرقام)',
                  ),
                  maxLength: 6,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'هذا الحقل مطلوب';
                    if (text.length != 6) return 'الرمز يجب أن يكون 6 أرقام';
                    if (int.tryParse(text) == null) return 'أدخل أرقام فقط';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : verify,
                    child:
                        loading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('تحقق'),
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
