import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/account_deletion_service.dart';
import '/utils/ui_helpers.dart';

import 'package:go_router/go_router.dart';

class AccountDeletionStatusScreen extends StatefulWidget {
  const AccountDeletionStatusScreen({super.key});

  @override
  State<AccountDeletionStatusScreen> createState() =>
      _AccountDeletionStatusScreenState();
}

class _AccountDeletionStatusScreenState
    extends State<AccountDeletionStatusScreen> {
  final AccountDeletionService deletionService = AccountDeletionService();

  bool loading = true;
  String? errorMessage;

  String statusMessage = '';
  bool canRequestDeletion = false;

  // نفترض مفعل إلى أن نقرأ من SharedPreferences
  bool isActive = true;

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  Future<void> loadStatus() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null;
      statusMessage = '';
      canRequestDeletion = false;
    });

    try {
      // 1) قراءة حالة التفعيل من SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedIsActive = prefs.getBool('user_is_active');

      if (!mounted) return;

      isActive = savedIsActive == true;

      // مستخدم غير مفعّل
      if (!isActive) {
        setState(() {
          statusMessage =
              'حسابك غير مفعّل حالياً.\nيرجى انتظار تفعيل الإدارة أو مراجعة الجهة المسؤولة.';
          loading = false;
          canRequestDeletion = false;
        });
        return;
      }

      // 2) الحساب مفعّل → نجلب طلبات الحذف الخاصة بالمستخدم
      final requests = await deletionService.fetchMyDeletionRequests();

      if (!mounted) return;

      // لا يوجد أي طلبات
      if (requests.isEmpty) {
        setState(() {
          statusMessage = 'لا يوجد طلب حذف حساب فعّال حاليًا.';
          canRequestDeletion = true;
          loading = false;
        });
        return;
      }

      // وجود طلبات: نطبّق ترتيب الأولوية

      // 1) هل يوجد طلب بحالة pending؟
      final hasPending = requests.any((request) {
        final status = (request['status']?.toString().toLowerCase() ?? '');
        return status == 'pending';
      });

      if (hasPending) {
        setState(() {
          statusMessage =
              'لديك طلب حذف حساب قيد المراجعة (بانتظار موافقة الإدارة).';
          canRequestDeletion = false;
          loading = false;
        });
        return;
      }

      // 2) لا يوجد pending → نأخذ آخر طلب (الأحدث)
      final latestRequest = requests.first;
      final latestStatus =
          latestRequest['status']?.toString().toLowerCase() ?? '';

      if (latestStatus == 'rejected') {
        setState(() {
          statusMessage = 'تم رفض طلب حذف حسابك الأخير.';
          canRequestDeletion = true;
          loading = false;
        });
        return;
      }

      if (latestStatus == 'approved') {
        // تمت الموافقة سابقاً ثم أعيد تفعيل الحساب
        setState(() {
          statusMessage =
              'تمت الموافقة على طلب حذف سابق، ثم تمت إعادة تفعيل حسابك بواسطة الإدارة.\n'
              'لا يوجد حاليًا طلب حذف حساب فعّال.';
          canRequestDeletion = true;
          loading = false;
        });
        return;
      }

      // 3) حالة احتياطية
      setState(() {
        statusMessage =
            'لا يوجد طلب حذف حساب فعّال حاليًا.\n(آخر حالة معروفة: $latestStatus)';
        canRequestDeletion = true;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'حدث خطأ أثناء تحميل حالة طلب حذف الحساب.';
        loading = false;
        canRequestDeletion = false;
      });
    }
  }

  Future<void> openDeletionRequestDialog() async {
    final reasonController = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
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

      if (!mounted) return; // هذا هو الحارس الصحيح لـ State.context

      if (confirmed != true) return;

      final success = await deletionService.createDeletionRequest(
        reason: reasonController.text,
      );

      if (!mounted) return;

      showAppSnackBar(
        context,
        success
            ? 'تم إرسال طلب حذف الحساب بنجاح.'
            : 'فشل إرسال طلب حذف الحساب، حاول مرة أخرى.',
        type: success ? AppSnackBarType.success : AppSnackBarType.error,
      );

      if (success) {
        await loadStatus();
        // loadStatus فيها setState داخلي مع mounted، ممتاز
      }
    } finally {
      reasonController.dispose();
    }
  }

  Widget statusView({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: iconColor),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStatusContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final msg = statusMessage;

    if (msg.contains('قيد المراجعة')) {
      return statusView(
        icon: Icons.hourglass_top,
        iconColor: cs.tertiary,
        title: 'طلب حذف الحساب قيد المراجعة',
        message: statusMessage,
      );
    }

    if (msg.contains('تم رفض')) {
      return statusView(
        icon: Icons.cancel_outlined,
        iconColor: cs.secondary,
        title: 'تم رفض طلب حذف الحساب',
        message: statusMessage,
      );
    }

    if (msg.contains('تمت الموافقة')) {
      return statusView(
        icon: Icons.manage_accounts_outlined,
        iconColor: cs.primary,
        title: 'تمت الموافقة على طلب حذف سابق',
        message: statusMessage,
      );
    }

    return statusView(
      icon: Icons.info_outline,
      iconColor: cs.outline,
      title: 'حالة طلب حذف الحساب',
      message: statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false, // نمنع الرجوع الافتراضي
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/app/account'); // الرجوع إلى صفحة الاعدادات
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('حالة طلب حذف الحساب'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                context.go('/app/account'); // نفس السلوك عند الضغط على السهم
              },
            ),
          ),
          body:
              loading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                  ? statusView(
                    icon: Icons.error_outline,
                    iconColor: cs.error,
                    title: 'حدث خطأ',
                    message: errorMessage!,
                  )
                  : buildStatusContent(context),
          bottomNavigationBar:
              (!loading &&
                      errorMessage == null &&
                      canRequestDeletion &&
                      isActive)
                  ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: openDeletionRequestDialog,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('إرسال طلب حذف حساب'),
                        ),
                      ),
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}
