import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ForgetPinScreen extends StatelessWidget {
  const ForgetPinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('نسيت رمز PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_reset, size: 64, color: cs.primary),
                    const SizedBox(height: 16),

                    Text(
                      'نسيت رمز PIN؟',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'في هذه المرحلة من التطوير، يمكن إعادة تعيين رمز PIN عن طريق تسجيل الدخول من جديد بحسابك (البريد وكلمة المرور)، ثم تعيين PIN جديد لاحقاً.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: const Icon(Icons.login),
                        label: const Text('العودة إلى تسجيل الدخول'),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('رجوع'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
