import 'package:flutter/material.dart';
import '/services/pin_service.dart';

class EnterPinScreen extends StatefulWidget {
  const EnterPinScreen({super.key});

  @override
  State<EnterPinScreen> createState() => _EnterPinScreenState();
}

class _EnterPinScreenState extends State<EnterPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pin = TextEditingController();
  bool _checking = false;
  String? _error;

  Future<void> _checkPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    final savedPin = await PinService().getPin();
    final enteredPin = _pin.text.trim();

    if (!mounted) return;

    if (savedPin == null) {
      setState(() {
        _checking = false;
        _error = 'لم يتم تعيين PIN بعد.';
      });
      return;
    }

    if (savedPin == enteredPin) {
      // PIN صحيح → نكمل التدفق (حالياً نذهب إلى user-list)
      setState(() => _checking = false);
      Navigator.pushReplacementNamed(context, '/user-list');
    } else {
      setState(() {
        _checking = false;
        _error = 'رمز PIN غير صحيح.';
      });
    }
  }

  void _forgotPin() async {
    // في الإصدار الأول: نمسح الـ PIN ونعيد المستخدم إلى شاشة تسجيل الدخول
    await PinService().clearPin();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('إدخال رمز PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'من فضلك أدخل رمز PIN للدخول إلى التطبيق.',
                style: TextStyle(color: cs.onSurface), // ✅ تم الاستبدال هنا فقط
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _pin,
                decoration: const InputDecoration(labelText: 'رمز PIN'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'الرجاء إدخال رمز PIN';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              _checking
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _checkPin,
                    child: const Text('دخول'),
                  ),
              TextButton(
                onPressed: _forgotPin,
                child: const Text('نسيت رمز PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
