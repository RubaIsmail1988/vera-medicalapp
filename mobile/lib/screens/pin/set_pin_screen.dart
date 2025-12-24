import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/pin_service.dart';
import '/utils/ui_helpers.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController pin1Controller = TextEditingController();
  final TextEditingController pin2Controller = TextEditingController();

  bool saving = false;

  String? pinValidator(String? v) {
    final text = (v ?? '').trim();
    if (text.length != 4) return 'يجب أن يكون PIN من 4 أرقام';
    if (int.tryParse(text) == null) return 'أدخل أرقام فقط';
    return null;
  }

  Future<void> savePin() async {
    if (saving) return;
    if (!formKey.currentState!.validate()) return;

    final pin1 = pin1Controller.text.trim();
    final pin2 = pin2Controller.text.trim();

    if (pin1 != pin2) {
      showAppSnackBar(
        context,
        'الرمزان غير متطابقين',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => saving = true);

    await PinService().savePin(pin1);

    if (!mounted) return;
    setState(() => saving = false);

    showAppSnackBar(
      context,
      'تم حفظ رمز PIN بنجاح.',
      type: AppSnackBarType.success,
    );

    // بعد حفظ PIN نذهب للتدفق العادي (PIN غير مفعّل حالياً في النظام)
    context.go('/app');
  }

  @override
  void dispose() {
    pin1Controller.dispose();
    pin2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تعيين رمز PIN')),
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
                      Icon(Icons.shield_outlined, size: 56, color: cs.primary),
                      const SizedBox(height: 12),
                      Text(
                        'الرجاء تعيين رمز PIN من 4 أرقام لحماية التطبيق.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: pin1Controller,
                        decoration: const InputDecoration(
                          labelText: 'أدخل رمز PIN',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        enabled: !saving,
                        textInputAction: TextInputAction.next,
                        validator: pinValidator,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: pin2Controller,
                        decoration: const InputDecoration(
                          labelText: 'أعد إدخال رمز PIN',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 4,
                        enabled: !saving,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => savePin(),
                        validator: pinValidator,
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: saving ? null : savePin,
                          child:
                              saving
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('حفظ الرمز'),
                        ),
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
