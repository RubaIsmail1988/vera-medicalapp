import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart'; // لإتاحة toggleTheme()

import 'admin_home_screen.dart';
import 'user_list_screen.dart';
import 'deletion_requests_screen.dart';
import '../admin/hospital_list_screen.dart';
import '../admin/lab_list_screen.dart';
import '/services/auth_service.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  int currentIndex = 0;

  String? userName;
  String? userEmail;
  String? userRole;
  bool? isActive;
  bool loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    loadUserInfo();
  }

  Future<void> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('currentUserName');
    final savedEmail = prefs.getString('currentUserEmail');
    final savedRole = prefs.getString('currentUserRole');
    final savedIsActive = prefs.getBool('user_is_active');

    if (!mounted) return;

    setState(() {
      userName = savedName;
      userEmail = savedEmail;
      userRole = savedRole;
      isActive = savedIsActive;
      loadingUserInfo = false;
    });
  }

  Future<void> logout(BuildContext context) async {
    final authService = AuthService();
    await authService.logout();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Widget buildDashboardTab() {
    return const AdminHomeScreen();
  }

  Widget buildUsersTab() {
    return const UserListScreen();
  }

  Widget buildHospitalsTab() {
    return const HospitalListScreen();
  }

  Widget buildLabsTab() {
    return const LabListScreen();
  }

  Widget buildDeletionRequestsTab() {
    return const DeletionRequestsScreen();
  }

  Widget buildProfileTab(BuildContext context) {
    final roleLabel =
        (userRole ?? 'admin') == 'admin' ? 'أدمن' : (userRole ?? 'admin');

    final displayName =
        (userName != null && userName!.trim().isNotEmpty)
            ? userName!
            : 'مسؤول النظام';

    String activationText = 'الحالة: غير معروفة';
    Color activationColor = Colors.grey;

    if (isActive == true) {
      activationText = 'الحالة: مفعّل';
      activationColor = Colors.green;
    } else if (isActive == false) {
      activationText = 'الحالة: غير مفعّل';
      activationColor = Colors.orange;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings, size: 80),
            const SizedBox(height: 16),
            Text(displayName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'الدور: $roleLabel',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            if (userEmail != null && userEmail!.trim().isNotEmpty)
              Text(userEmail!, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              activationText,
              style: TextStyle(fontSize: 14, color: activationColor),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBody(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return buildDashboardTab();
      case 1:
        return buildUsersTab();
      case 2:
        return buildHospitalsTab();
      case 3:
        return buildLabsTab();
      case 4:
        return buildDeletionRequestsTab();
      case 5:
        return buildProfileTab(context);
      default:
        return buildDashboardTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = MyApp.of(context).themeMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentIndex == 0
              ? 'Dashboard'
              : currentIndex == 1
              ? 'Users'
              : currentIndex == 2
              ? 'Hospitals'
              : currentIndex == 3
              ? 'Labs'
              : currentIndex == 4
              ? 'طلبات الحذف'
              : 'Profile',
        ),

        // زر تبديل الثيم يظهر فقط في Dashboard
        actions:
            currentIndex == 0
                ? [
                  IconButton(
                    icon: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.brightness_6
                          : Icons.brightness_6_outlined,
                    ),
                    onPressed: () {
                      MyApp.of(context).toggleTheme();
                    },
                  ),
                ]
                : null,
      ),

      body: buildBody(context),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Hospitals',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Labs'),
          BottomNavigationBarItem(
            icon: Icon(Icons.delete_forever),
            label: 'Requests ',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
