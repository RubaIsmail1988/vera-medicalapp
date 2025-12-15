import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/account_deletion_service.dart';

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
  bool isActive = true; // نفترض مفعل إلى أن نقرأ من SharedPreferences

  @override
  void initState() {
    super.initState();
    loadStatus();
  }

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadStatus() async {
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

      // مستخدم غير مفعّل: حالة احتياطية، منطق B-1 أصلاً لا يسمح له بالدخول
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
      final hasPending = requests.any(
        (request) =>
            (request['status']?.toString().toLowerCase() ?? '') == 'pending',
      );

      if (hasPending) {
        setState(() {
          statusMessage =
              'لديك طلب حذف حساب قيد المراجعة (بانتظار موافقة الإدارة).';
          canRequestDeletion = false; // لا نسمح بطلب جديد مع وجود pending
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
          canRequestDeletion = true; // يمكنه إرسال طلب جديد
          loading = false;
        });
        return;
      }

      if (latestStatus == 'approved') {
        // حالة خاصة: تمت الموافقة على طلب سابق، لكن الحساب الآن مفعّل
        // (إعادة تفعيل بواسطة الأدمن)
        setState(() {
          statusMessage =
              'تمت الموافقة على طلب حذف سابق، ثم تمت إعادة تفعيل حسابك بواسطة الإدارة.\n'
              'لا يوجد حاليًا طلب حذف حساب فعّال.';
          canRequestDeletion = true;
          loading = false;
        });
        return;
      }

      // 3) حالة احتياطية لباقي الحالات
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

    if (!mounted) return;

    if (confirmed != true) return;

    final success = await deletionService.createDeletionRequest(
      reason: reasonController.text,
    );

    if (!mounted) return;

    showSnackBar(
      success
          ? 'تم إرسال طلب حذف الحساب بنجاح.'
          : 'فشل إرسال طلب حذف الحساب، حاول مرة أخرى.',
    );

    if (success) {
      await loadStatus();
    }
  }

  Widget _statusView({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(BuildContext context) {
    final msg = statusMessage.toLowerCase();

    if (msg.contains('قيد المراجعة')) {
      return _statusView(
        icon: Icons.hourglass_top,
        color: Colors.orange,
        title: 'طلب حذف الحساب قيد المراجعة',
        message: statusMessage,
      );
    }

    if (msg.contains('تم رفض')) {
      return _statusView(
        icon: Icons.cancel_outlined,
        color: Colors.blueGrey,
        title: 'تم رفض طلب حذف الحساب',
        message: statusMessage,
      );
    }

    if (msg.contains('تمت الموافقة')) {
      return _statusView(
        icon: Icons.manage_accounts_outlined,
        color: Colors.teal,
        title: 'تمت الموافقة على طلب حذف سابق',
        message: statusMessage,
      );
    }

    return _statusView(
      icon: Icons.info_outline,
      color: Colors.grey,
      title: 'حالة طلب حذف الحساب',
      message: statusMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حالة طلب حذف الحساب')),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? _statusView(
                icon: Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                title: 'حدث خطأ',
                message: errorMessage!,
              )
              : _buildStatusContent(context),
    );
  }
}
