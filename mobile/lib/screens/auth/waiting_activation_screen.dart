import 'package:flutter/material.dart';
import '../../widgets/app_logo.dart';

class WaitingActivationScreen extends StatelessWidget {
  const WaitingActivationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الحساب غير مفعّل')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppLogo(width: 220),
              const SizedBox(height: 20),

              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),

              const Text(
                'حسابك غير مفعّل حالياً من قبل الإدارة.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              const Text(
                'إذا كنت مستخدمًا جديدًا فقد يكون حسابك بانتظار التفعيل\n'
                'وإذا كنت قد طلبت حذف حسابك، فهذا يعني أنه تم تعطيله بناءً على طلبك\n'
                'للاستفسار يُرجى التواصل مع الإدارة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('العودة إلى تسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
