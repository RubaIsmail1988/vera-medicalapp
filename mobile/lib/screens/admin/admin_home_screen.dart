import 'package:flutter/material.dart';

import '../admin/hospital_list_screen.dart';
import '../admin/lab_list_screen.dart';
import 'user_list_screen.dart';
import '/services/auth_service.dart';
//import '/main.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();

    await authService.logout();

    // بعد await → يجب فحص mounted قبل استخدام context
    if (!context.mounted) return;

    // تنظيف الـ stack وإرجاع المستخدم لشاشة الدخول
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      // title: const Text("لوحة تحكم الأدمن"),
      //   actions: [
      //  IconButton(
      //   icon: const Icon(Icons.brightness_6),
      //   tooltip: 'تبديل الثيم',
      //   onPressed: () {
      //     MyApp.of(context).toggleTheme();
      //  },
      // ),
      //     IconButton(
      //      icon: const Icon(Icons.logout),
      //      tooltip: 'تسجيل الخروج',
      //      onPressed: () => logout(context),
      //   ),
      //   ],
      //  ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            adminButton(
              context,
              title: "إدارة المستخدمين",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserListScreen()),
                );
              },
            ),
            adminButton(
              context,
              title: "إدارة المشافي",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HospitalListScreen()),
                );
              },
            ),
            adminButton(
              context,
              title: "إدارة المخابر",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LabListScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget adminButton(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(onPressed: onTap, child: Text(title)),
    );
  }
}
