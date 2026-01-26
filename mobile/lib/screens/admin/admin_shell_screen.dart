import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../services/auth_service.dart';

import 'admin_home_screen.dart';
import 'deletion_requests_screen.dart';
import 'hospital_list_screen.dart';
import 'lab_list_screen.dart';
import 'user_list_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  late int currentIndex;

  String? userName;
  String? userEmail;
  String? userRole;
  bool? isActive;

  static const List<String> tabPaths = <String>[
    '/admin',
    '/admin/users',
    '/admin/hospitals',
    '/admin/labs',
    '/admin/requests',
    '/admin/profile',
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    loadUserInfo();
  }

  @override
  void didUpdateWidget(covariant AdminShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() => currentIndex = widget.initialIndex);
    }
  }

  void goToTab(int index) {
    if (index < 0 || index >= tabPaths.length) return;

    context.go(tabPaths[index]);
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
    });
  }

  Future<void> logout() async {
    final authService = AuthService();
    await authService.logout();

    if (!mounted) return;
    context.go('/login');
  }

  Widget buildProfileTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final roleLabel =
        (userRole ?? 'admin') == 'admin' ? 'أدمن' : (userRole ?? 'admin');

    final displayName =
        (userName != null && userName!.trim().isNotEmpty)
            ? userName!
            : 'مسؤول النظام';

    String activationText = 'الحالة: غير معروفة';
    Color activationColor = cs.onSurface.withValues(alpha: 0.60);

    if (isActive == true) {
      activationText = 'الحالة: مفعّل';
      activationColor = cs.primary;
    } else if (isActive == false) {
      activationText = 'الحالة: غير مفعّل';
      activationColor = cs.error;
    }

    return Center(
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
                  Icon(Icons.admin_panel_settings, size: 76, color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الدور: $roleLabel',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  if (userEmail != null && userEmail!.trim().isNotEmpty)
                    Text(
                      userEmail!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    activationText,
                    style: TextStyle(fontSize: 14, color: activationColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String appBarTitle() {
    switch (currentIndex) {
      case 0:
        return 'لوحة التحكم';
      case 1:
        return 'المستخدمون';
      case 2:
        return 'المشافي';
      case 3:
        return 'المخابر';
      case 4:
        return 'طلبات الحذف';
      case 5:
        return 'الملف الشخصي';
      default:
        return 'لوحة التحكم';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = MyApp.of(context).themeMode;

    final pages = <Widget>[
      AdminHomeScreen(onNavigateToTab: (index) => goToTab(index)),
      UserListScreen(onOpenDeletionRequests: () => goToTab(4)),
      const HospitalListScreen(),
      const LabListScreen(),
      const DeletionRequestsScreen(),
      buildProfileTab(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle()),
        actions:
            currentIndex == 0
                ? [
                  IconButton(
                    icon: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.brightness_6
                          : Icons.brightness_6_outlined,
                    ),
                    onPressed: () => MyApp.of(context).toggleTheme(),
                  ),
                ]
                : null,
      ),
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: goToTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'لوحة التحكم',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'المستخدمون'),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'المشافي',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'المخابر'),
          BottomNavigationBarItem(
            icon: Icon(Icons.delete_forever),
            label: 'طلبات الحذف',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'الملف الشخصي',
          ),
        ],
      ),
    );
  }
}
