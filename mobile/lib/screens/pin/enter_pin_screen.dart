import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/pin_service.dart';
import '/utils/ui_helpers.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController pinController = TextEditingController();

  bool checking = false;

  Future<void> checkPin() async {
    if (checking) return;
    if (!formKey.currentState!.validate()) return;

    setState(() => checking = true);

    final savedPin = await PinService().getPin();
    final enteredPin = pinController.text.trim();

    if (!mounted) return;

    if (savedPin == null) {
      setState(() => checking = false);
      showAppSnackBar(
        context,
        'لم يتم تعيين PIN بعد.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (savedPin == enteredPin) {
      setState(() => checking = false);

      // PIN صحيح → نكمل التدفق (PIN غير مفعّل حالياً في النظام)
      // fallback آمن: الذهاب إلى التطبيق الرئيسي
      context.go('/app');
      return;
    }

    setState(() => checking = false);
    showAppSnackBar(context, 'رمز PIN غير صحيح.', type: AppSnackBarType.error);
  }

  Future<void> forgotPin() async {
    if (checking) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'نسيت رمز PIN',
      message:
          'سيتم مسح رمز PIN المحفوظ وسيتم إعادتك إلى شاشة تسجيل الدخول. هل تريد المتابعة؟',
      confirmText: 'متابعة',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!confirmed) return;

    await PinService().clearPin();
    if (!mounted) return;

    showAppSnackBar(
      context,
      'تم مسح رمز PIN. يمكنك تسجيل الدخول الآن.',
      type: AppSnackBarType.info,
    );

    context.go('/login');
  }

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('إدخال رمز PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 56, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'من فضلك أدخل رمز PIN للدخول إلى التطبيق.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: pinController,
                        decoration: const InputDecoration(labelText: 'رمز PIN'),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        enabled: !checking,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => checkPin(),
                        validator: (v) {
                          final text = (v ?? '').trim();
                          if (text.isEmpty) return 'الرجاء إدخال رمز PIN';
                          if (text.length != 4) {
                            return 'رمز PIN يجب أن يكون 4 أرقام';
                          }
                          if (int.tryParse(text) == null) {
                            return 'أدخل أرقام فقط';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: checking ? null : checkPin,
                          child:
                              checking
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('دخول'),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: checking ? null : forgotPin,
                        child: const Text('نسيت رمز PIN'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
