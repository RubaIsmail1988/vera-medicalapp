import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doctor_details_entry_point.dart';
import '/services/account_deletion_service.dart';
import 'account_deletion_status_screen.dart';

// Phase C (Doctor Scheduling Settings)
import '../doctor/doctor_scheduling_settings_screen.dart';

// UI Helpers
import '../../utils/ui_helpers.dart';

class DoctorHomeScreen extends StatefulWidget {
  final int userId;
  final String token;

  const DoctorHomeScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final AccountDeletionService deletionService = AccountDeletionService();

  String? userName;
  bool loadingName = true;

  @override
  void initState() {
    super.initState();
    loadUserName();
  }

  Future<void> loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('currentUserName');

    if (!mounted) return;

    setState(() {
      userName = savedName;
      loadingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final greeting =
        (userName != null && userName!.trim().isNotEmpty)
            ? 'أهلاً بك يا ${userName!}'
            : 'أهلاً بك';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'يمكنك من هنا إدارة بياناتك وطلباتك.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),

              // عرض / تعديل بيانات الطبيب
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
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
                  },
                  child: const Text('عرض / تعديل بيانات الطبيب'),
                ),
              ),

              const SizedBox(height: 12),

              // Phase C - إعدادات الجدولة
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DoctorSchedulingSettingsScreen(),
                      ),
                    );
                  },
                  child: const Text('إعدادات الجدولة'),
                ),
              ),

              const SizedBox(height: 12),

              // زر طلب حذف الحساب
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final reasonController = TextEditingController();

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
                              onPressed: () {
                                Navigator.pop(dialogContext, false);
                              },
                              child: const Text('إلغاء'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, true);
                              },
                              child: const Text('تأكيد الطلب'),
                            ),
                          ],
                        );
                      },
                    );

                    if (!context.mounted) {
                      return;
                    }

                    if (confirmed != true) {
                      return;
                    }

                    final success = await deletionService.createDeletionRequest(
                      reason: reasonController.text,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    showAppSnackBar(
                      context,
                      success
                          ? 'تم إرسال طلب حذف الحساب بنجاح.'
                          : 'فشل إرسال طلب حذف الحساب، حاول مرة أخرى.',
                    );
                  },

                  child: const Text('طلب حذف الحساب'),
                ),
              ),

              const SizedBox(height: 8),

              // زر عرض حالة طلب الحذف
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountDeletionStatusScreen(),
                    ),
                  );
                },
                child: const Text('عرض حالة طلب حذف الحساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
