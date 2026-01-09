import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '/services/auth_service.dart';
import '/services/account_deletion_service.dart';
import '../../utils/ui_helpers.dart';

import 'patient_home_screen.dart';
import 'doctor_home_screen.dart';
import 'hospital_public_list_screen.dart';
import 'lab_public_list_screen.dart';
import 'unified_record_screen.dart';
import 'appointments/my_appointments_screen.dart';

class UserShellScreen extends StatefulWidget {
  const UserShellScreen({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<UserShellScreen> createState() => _UserShellScreenState();
}

class _UserShellScreenState extends State<UserShellScreen> {
  late int currentIndex;

  // Session from prefs
  String role = 'patient';
  int userId = 0;
  String token = '';

  // Profile
  String? userName;
  String? userEmail;
  String? userRole;
  bool? isActive;

  bool loading = true;

  final AccountDeletionService deletionService = AccountDeletionService();

  static const List<String> tabPaths = <String>[
    '/app',
    '/app/record',
    '/app/hospitals',
    '/app/labs',
    '/app/account',
    '/app/appointments',
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    loadSession();
  }

  @override
  void didUpdateWidget(covariant UserShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      if (!mounted) return;
      setState(() => currentIndex = widget.initialIndex);
    }
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    final savedToken = prefs.getString('access_token') ?? '';
    final savedRole = prefs.getString('user_role') ?? 'patient';
    final savedUserId = prefs.getInt('user_id') ?? 0;

    final savedName = prefs.getString('currentUserName');
    final savedEmail = prefs.getString('currentUserEmail');
    final savedBackendRole = prefs.getString('currentUserRole');
    final savedIsActive = prefs.getBool('user_is_active');

    if (!mounted) return;

    setState(() {
      token = savedToken;
      role = savedRole;
      userId = savedUserId;

      userName = savedName;
      userEmail = savedEmail;
      userRole = savedBackendRole;
      isActive = savedIsActive;

      loading = false;
    });

    final invalidSession =
        token.isEmpty || userId == 0 || (role != 'patient' && role != 'doctor');

    if (invalidSession) {
      if (!mounted) return;
      context.go('/login');
      return;
    }

    if (role == 'doctor' && isActive == false) {
      if (!mounted) return;
      context.go('/waiting-activation');
      return;
    }
  }

  Future<void> logout() async {
    final authService = AuthService();
    await authService.logout();

    if (!mounted) return;
    context.go('/login');
  }

  void goToTab(int index) {
    if (index < 0 || index >= tabPaths.length) return;
    if (!mounted) return;

    // لا نعمل setState هنا — الـ route سيعيد بناء UserShellScreen بالـ initialIndex الصحيح
    context.go(tabPaths[index]);
  }

  Widget buildHomeTab() {
    if (role == 'doctor') {
      return DoctorHomeScreen(userId: userId, token: token);
    }
    return PatientHomeScreen(userId: userId, token: token);
  }

  void openDetails(String roleFromBackend) {
    if (!mounted) return;
    if (token.isEmpty || userId == 0) return;

    final extra = {'token': token, 'userId': userId};

    if (roleFromBackend == 'patient') {
      context.go('/app/account/patient-details', extra: extra);
      return;
    }
    if (roleFromBackend == 'doctor') {
      context.go('/app/account/doctor-details', extra: extra);
      return;
    }
  }

  Future<void> requestAccountDeletion(BuildContext context) async {
    final reasonController = TextEditingController();

    try {
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('طلب حذف الحساب'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'هل أنت متأكد من رغبتك في طلب حذف حسابك؟\n'
                  'سيتم مراجعة الطلب من قبل الإدارة.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الطلب (اختياري)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('تأكيد الطلب'),
              ),
            ],
          );
        },
      );

      if (!context.mounted) return;
      if (confirmed != true) return;

      final reason = reasonController.text.trim();
      final success = await deletionService.createDeletionRequest(
        reason: reason,
      );

      if (!context.mounted) return;

      showAppSnackBar(
        context,
        success ? 'تم إرسال طلب حذف الحساب بنجاح.' : 'لديك طلب قيد المراجعة.',
        type: success ? AppSnackBarType.success : AppSnackBarType.error,
      );
    } finally {
      reasonController.dispose();
    }
  }

  Widget buildAccountTab(BuildContext context) {
    final roleFromBackend = userRole ?? role;

    final roleLabel =
        roleFromBackend == 'doctor'
            ? 'طبيب'
            : roleFromBackend == 'patient'
            ? 'مريض'
            : roleFromBackend;

    final displayName =
        (userName != null && userName!.trim().isNotEmpty)
            ? userName!
            : 'مستخدم';

    String activationText = 'الحالة: غير معروفة';
    Color activationColor = Colors.grey;

    if (isActive == true) {
      activationText = 'الحالة: مفعّل';
      activationColor = Colors.green;
    } else if (isActive == false) {
      activationText = 'الحالة: غير مفعّل';
      activationColor = Colors.orange;
    }

    final bool canOpenDetails =
        token.isNotEmpty &&
        userId != 0 &&
        (roleFromBackend != 'doctor' || isActive == true);

    final bool isDoctor = roleFromBackend == 'doctor';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_circle, size: 80),
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

              // عرض / تعديل البيانات
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      canOpenDetails
                          ? () => openDetails(roleFromBackend)
                          : null,
                  child: const Text('عرض / تعديل البيانات'),
                ),
              ),

              // إعدادات الجدولة (للطبيب فقط)
              if (isDoctor) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/app/doctor/scheduling'),
                    child: const Text('إعدادات الجدولة'),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // طلب حذف الحساب (للطبيب والمريض)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => requestAccountDeletion(context),
                  child: const Text('طلب حذف الحساب'),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: () => context.go('/app/account/deletion-status'),
                child: const Text('عرض حالة طلب حذف الحساب'),
              ),

              const SizedBox(height: 16),

              // تسجيل الخروج
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
    );
  }

  Widget buildBody(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return buildHomeTab();
      case 1:
        return UnifiedRecordScreen(role: role, userId: userId);
      case 2:
        return const HospitalPublicListScreen();
      case 3:
        return const LabPublicListScreen();
      case 4:
        return buildAccountTab(context);
      case 5:
        return const MyAppointmentsScreen();
      default:
        return buildHomeTab();
    }
  }

  String appBarTitle() {
    switch (currentIndex) {
      case 0:
        return role == 'doctor'
            ? 'الصفحة الرئيسية - الطبيب'
            : 'الصفحة الرئيسية - المريض';
      case 1:
        return 'الإضبارة الطبية';
      case 2:
        return 'المشافي';
      case 3:
        return 'المخابر';
      case 4:
        return 'الحساب';
      case 5:
        return 'المواعيد';
      default:
        return 'Vera Smart Health';
    }
  }

  Widget? _buildFloatingActionButton() {
    final bool isAppointmentsTab = currentIndex == 5;
    final bool canBook = role == 'patient';

    if (!isAppointmentsTab || !canBook) return null;

    return FloatingActionButton.extended(
      onPressed: () => context.go('/app/appointments/book'),
      icon: const Icon(Icons.add),
      label: const Text('حجز موعد'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = MyApp.of(context).themeMode;

    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      floatingActionButton: _buildFloatingActionButton(),
      body: buildBody(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: goToTab,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_shared),
            label: 'الإضبارة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'المشافي',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'المخابر'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'الحساب'),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'المواعيد',
          ),
        ],
      ),
    );
  }
}
