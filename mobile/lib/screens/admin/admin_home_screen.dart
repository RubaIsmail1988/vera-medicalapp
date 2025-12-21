import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            adminButton(
              title: "إدارة المستخدمين",
              onTap: () => onNavigateToTab(1),
            ),
            adminButton(
              title: "إدارة المشافي",
              onTap: () => onNavigateToTab(2),
            ),
            adminButton(
              title: "إدارة المخابر",
              onTap: () => onNavigateToTab(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget adminButton({required String title, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: ElevatedButton(onPressed: onTap, child: Text(title)),
      ),
    );
  }
}
