// ----------------- mobile/lib/screens/user/user_shell_screen.dart -----------------
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

import '/analytics/doctor_home_analytics.dart';
import '/analytics/doctor_analytics_sheet.dart';

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
  DoctorAnalytics? _doctorAnalytics;

  final AccountDeletionService deletionService = AccountDeletionService();

  static const List<String> tabPaths = <String>[
    '/app', // 0 الرئيسية
    '/app/appointments', // 1 المواعيد
    '/app/record', // 2 الإضبارة
    '/app/hospitals', // 3 المشافي
    '/app/labs', // 4 المخابر
    '/app/account', // 5 الحساب
  ];

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    // ignore: unawaited_futures
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

    // IMPORTANT:
    // Polling is managed centrally in MyAppState only.
    // Do NOT start polling here.
  }

  Future<void> logout() async {
    final app = MyApp.of(context);
    await app.stopPolling();

    final authService = AuthService();
    await authService.logout();

    if (!mounted) return;
    context.go('/login');
  }

  void goToTab(int index) {
    if (index < 0 || index >= tabPaths.length) return;
    if (!mounted) return;

    context.go(tabPaths[index]);
  }

  Widget buildHomeTab() {
    if (role == 'doctor') {
      return DoctorHomeScreen(
        userId: userId,
        token: token,
        onAnalyticsLoaded: (a) {
          if (!mounted) return;
          setState(() => _doctorAnalytics = a);
        },
      );
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

  void _openDoctorAnalyticsSheet(DoctorAnalytics analytics) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: DoctorAnalyticsSheet(analytics: analytics),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> requestAccountDeletion(BuildContext context) async {
    //  Dialog returns the reason string (or null if cancelled)
    final String? reason = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AccountDeletionDialog(),
    );

    if (!context.mounted) return;
    if (reason == null) return; // cancelled

    //  Action network call must be caught to avoid Red Screen
    try {
      final success = await deletionService.createDeletionRequest(
        reason: reason.trim(),
      );

      if (!context.mounted) return;

      showAppSnackBar(
        context,
        success ? 'تم إرسال طلب حذف الحساب بنجاح.' : 'لديك طلب قيد المراجعة.',
        type: success ? AppSnackBarType.success : AppSnackBarType.error,
      );
    } catch (e) {
      if (!context.mounted) return;
      showActionErrorSnackBar(context, exception: e);
    }
  }

  Widget buildAccountTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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

    final bool isDoctor = roleFromBackend == 'doctor';

    final bool canOpenDetails =
        token.isNotEmpty &&
        userId != 0 &&
        (roleFromBackend != 'doctor' || isActive == true);

    final String activationText;
    final Color activationColor;

    if (isActive == true) {
      activationText = 'الحالة: مفعّل';
      activationColor = cs.primary;
    } else if (isActive == false) {
      activationText = 'الحالة: غير مفعّل';
      activationColor = cs.error;
    } else {
      activationText = 'الحالة: غير معروفة';
      activationColor = cs.onSurface.withValues(alpha: 0.60);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_circle,
                  size: 84,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الدور: $roleLabel',
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.80),
                  ),
                ),
                if (userEmail != null && userEmail!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    userEmail!,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  activationText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: activationColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        canOpenDetails
                            ? () => openDetails(roleFromBackend)
                            : null,
                    child: const Text('عرض / تعديل البيانات'),
                  ),
                ),

                if (isDoctor) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/app/doctor/scheduling'),
                      child: const Text('إعدادات الجدولة'),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                Divider(color: cs.onSurface.withValues(alpha: 0.12)),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => requestAccountDeletion(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: cs.error.withValues(alpha: 0.75)),
                      foregroundColor: cs.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('طلب حذف الحساب'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => context.go('/app/account/deletion-status'),
                  child: const Text('عرض حالة طلب حذف الحساب'),
                ),

                const SizedBox(height: 18),
                Divider(color: cs.onSurface.withValues(alpha: 0.12)),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
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
    );
  }

  Widget buildBody(BuildContext context) {
    switch (currentIndex) {
      case 0:
        return buildHomeTab();
      case 1:
        return const MyAppointmentsScreen();
      case 2:
        return UnifiedRecordScreen(role: role, userId: userId);
      case 3:
        return const HospitalPublicListScreen();
      case 4:
        return const LabPublicListScreen();
      case 5:
        return buildAccountTab(context);
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
        return 'المواعيد';
      case 2:
        return 'الإضبارة الطبية';
      case 3:
        return 'المشافي';
      case 4:
        return 'المخابر';
      case 5:
        return 'الحساب';
      default:
        return 'Vera Smart Health';
    }
  }

  Widget? _buildFloatingActionButton() {
    final bool isAppointmentsTab = currentIndex == 1;
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
        automaticallyImplyLeading: false,
        title: Text(appBarTitle()),
        actions:
            currentIndex == 0
                ? [
                  // 1) Analytics (doctor only)
                  if (role == 'doctor')
                    IconButton(
                      tooltip: 'تحليلات آخر 30 يوم',
                      icon: const Icon(Icons.bar_chart_rounded),
                      onPressed:
                          (_doctorAnalytics == null)
                              ? null
                              : () =>
                                  _openDoctorAnalyticsSheet(_doctorAnalytics!),
                    ),

                  // 2) Theme toggle
                  IconButton(
                    icon: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.brightness_6
                          : Icons.brightness_6_outlined,
                    ),
                    onPressed: () => MyApp.of(context).toggleTheme(),
                  ),

                  // 3) Inbox bell
                  IconButton(
                    tooltip: "Inbox",
                    icon: const Icon(Icons.notifications),
                    onPressed: () => context.go('/app/inbox'),
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
            icon: Icon(Icons.event_available),
            label: 'المواعيد',
          ),
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog (Stateful): isolates TextEditingController lifecycle
// ---------------------------------------------------------------------------

class _AccountDeletionDialog extends StatefulWidget {
  const _AccountDeletionDialog();

  @override
  State<_AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<_AccountDeletionDialog> {
  final TextEditingController reasonController = TextEditingController();

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('طلب حذف الحساب', textAlign: TextAlign.right),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'هل أنت متأكد من رغبتك في طلب حذف حسابك؟\n'
                'سيتم مراجعة الطلب من قبل الإدارة.',
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب الطلب (اختياري)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              Navigator.pop(context, reason);
            },
            child: const Text('تأكيد الطلب'),
          ),
        ],
      ),
    );
  }
}
