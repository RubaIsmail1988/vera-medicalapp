import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart'; // لاستدعاء MyApp.of(context)
import 'patient_home_screen.dart';
import 'doctor_home_screen.dart';
import 'hospital_public_list_screen.dart';
import 'lab_public_list_screen.dart';
import 'patient_details_entry_point.dart';
import 'doctor_details_entry_point.dart';
import 'unified_record_screen.dart';
import '/services/auth_service.dart';

class UserShellScreen extends StatefulWidget {
  final String role;
  final int userId;
  final String token;

  const UserShellScreen({
    super.key,
    required this.role,
    required this.userId,
    required this.token,
  });

  @override
  State<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends State<UserShellScreen> {
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

    final savedName = prefs.getString("currentUserName");
    final savedEmail = prefs.getString("currentUserEmail");
    final savedRole = prefs.getString("currentUserRole");
    final savedIsActive = prefs.getBool("user_is_active");

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

    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }

  Widget buildHomeTab() {
    if (widget.role == "doctor") {
      return DoctorHomeScreen(userId: widget.userId, token: widget.token);
    } else {
      return PatientHomeScreen(userId: widget.userId, token: widget.token);
    }
  }

  Widget buildAccountTab(BuildContext context) {
    final roleFromBackend = userRole ?? widget.role;

    final roleLabel =
        roleFromBackend == "doctor"
            ? "طبيب"
            : roleFromBackend == "patient"
            ? "مريض"
            : roleFromBackend;

    final displayName =
        (userName != null && userName!.trim().isNotEmpty)
            ? userName!
            : "مستخدم";

    String activationText = "الحالة: غير معروفة";
    Color activationColor = Colors.grey;

    if (isActive == true) {
      activationText = "الحالة: مفعّل";
      activationColor = Colors.green;
    } else if (isActive == false) {
      activationText = "الحالة: غير مفعّل";
      activationColor = Colors.orange;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle, size: 80),
            const SizedBox(height: 16),
            Text(displayName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              "الدور: $roleLabel",
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

            // زر عرض / تعديل البيانات
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (roleFromBackend == "patient") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PatientDetailsEntryPoint(
                              token: widget.token,
                              userId: widget.userId,
                            ),
                      ),
                    );
                  } else if (roleFromBackend == "doctor") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => DoctorDetailsEntryPoint(
                              token: widget.token,
                              userId: widget.userId,
                            ),
                      ),
                    );
                  }
                },
                child: const Text("عرض / تعديل البيانات"),
              ),
            ),

            const SizedBox(height: 16),

            // زر تسجيل الخروج
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => logout(context),
                icon: const Icon(Icons.logout),
                label: const Text("تسجيل الخروج"),
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
        return buildHomeTab();
      case 1:
        return UnifiedRecordScreen(role: widget.role, userId: widget.userId);
      case 2:
        return const HospitalPublicListScreen();
      case 3:
        return const LabPublicListScreen();
      case 4:
        return buildAccountTab(context);
      default:
        return buildHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = MyApp.of(context).themeMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          currentIndex == 0
              ? (widget.role == "doctor"
                  ? "الصفحة الرئيسية - الطبيب"
                  : "الصفحة الرئيسية - المريض")
              : currentIndex == 1
              ? "الإضبارة الطبية"
              : currentIndex == 2
              ? "المشافي"
              : currentIndex == 3
              ? "المخابر"
              : "الحساب",
        ),

        // زر تبديل الثيم يظهر فقط في Dashboard (التبويب 0)
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "الرئيسية"),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: "الأضبارة",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: "المشافي",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: "المخابر"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "الحساب"),
        ],
      ),
    );
  }
}
