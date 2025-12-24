import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_logo.dart';

class WaitingActivationScreen extends StatelessWidget {
  const WaitingActivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الحساب غير مفعّل')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(width: 220),
                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 64,
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'حسابك غير مفعّل حالياً من قبل الإدارة.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          'إذا كنت مستخدمًا جديدًا فقد يكون حسابك بانتظار التفعيل.\n'
                          'وإذا كنت قد طلبت حذف حسابك، فقد يكون الحساب معطّلًا بناءً على طلبك.\n'
                          'للاستفسار، يُرجى التواصل مع الإدارة.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('العودة إلى تسجيل الدخول'),
                          ),
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
    );
  }
}
