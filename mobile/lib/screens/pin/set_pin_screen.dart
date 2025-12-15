import 'package:flutter/material.dart';
import '/services/pin_service.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _pin1 = TextEditingController();
  final TextEditingController _pin2 = TextEditingController();

  bool _saving = false;

  Future<void> _savePin() async {
    if (!_formKey.currentState!.validate()) return;

    final pin1 = _pin1.text.trim();
    final pin2 = _pin2.text.trim();

    if (pin1 != pin2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرمزان غير متطابقين')));
      return;
    }

    setState(() => _saving = true);

    await PinService().savePin(pin1);

    if (!mounted) return;
    setState(() => _saving = false);

    // بعد حفظ PIN نذهب للتدفق العادي (مثلاً user-list حالياً)
    Navigator.pushReplacementNamed(context, '/user-list');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تعيين رمز PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'الرجاء تعيين رمز PIN من 4 أرقام لحماية التطبيق.',
                style: TextStyle(color: cs.onSurface),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _pin1,
                decoration: const InputDecoration(labelText: 'أدخل رمز PIN'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                validator: (v) {
                  if (v == null || v.trim().length != 4) {
                    return 'يجب أن يكون PIN من 4 أرقام';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _pin2,
                decoration: const InputDecoration(
                  labelText: 'أعد إدخال رمز PIN',
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                validator: (v) {
                  if (v == null || v.trim().length != 4) {
                    return 'يجب أن يكون PIN من 4 أرقام';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _savePin,
                    child: const Text('حفظ الرمز'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
