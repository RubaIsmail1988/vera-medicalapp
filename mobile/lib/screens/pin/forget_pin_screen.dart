import 'package:flutter/material.dart';

class ForgetPinScreen extends StatelessWidget {
  const ForgetPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('نسيت رمز الـ PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock_reset, size: 72, color: colorScheme.primary),
            const SizedBox(height: 24),

            const Text(
              'نسيت رمز الـ PIN؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Text(
              'في هذه المرحلة من التطوير، يمكن إعادة تعيين رمز الـ PIN عن طريق تسجيل الدخول من جديد بحسابك (البريد وكلمة المرور)، '
              'ثم تعيين PIN جديد لاحقاً.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                // لاحقاً يمكن إضافة منطق مسح الـ PIN المحلي هنا
                // حالياً نعيد المستخدم لشاشة تسجيل الدخول فقط
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.login),
              label: const Text('العودة إلى تسجيل الدخول'),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('رجوع'),
            ),
          ],
        ),
      ),
    );
  }
}
