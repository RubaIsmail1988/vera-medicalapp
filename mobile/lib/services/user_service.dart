import 'package:flutter/material.dart';

import '../services/admin_user_service.dart';
import '/utils/ui_helpers.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final AdminUserService adminService = AdminUserService();
  late Future<List<Map<String, dynamic>>> futureUsers;

  @override
  void initState() {
    super.initState();
    futureUsers = adminService.fetchAllUsers();
  }

  Future<void> refresh() async {
    setState(() {
      futureUsers = adminService.fetchAllUsers();
    });
  }

  Future<void> toggleActivation(Map<String, dynamic> user) async {
    final int userId = user['id'] as int;
    final bool isActive = user['is_active'] as bool? ?? false;

    try {
      final bool success =
          isActive
              ? await adminService.deactivateUser(userId)
              : await adminService.activateUser(userId);

      if (!mounted) return;

      if (success) {
        showAppSnackBar(
          context,
          isActive ? 'تم تعطيل المستخدم بنجاح.' : 'تم تفعيل المستخدم بنجاح.',
          type: AppSnackBarType.success,
        );
        await refresh();
      } else {
        showAppSnackBar(
          context,
          isActive ? 'فشل تعطيل المستخدم.' : 'فشل تفعيل المستخدم.',
          type: AppSnackBarType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'حدث خطأ أثناء تحديث حالة المستخدم.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة المستخدمين')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: futureUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('حدث خطأ أثناء تحميل المستخدمين.'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('لا يوجد مستخدمون.'));
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final bool isActive = user['is_active'] as bool? ?? false;
                final String role = user['role']?.toString() ?? '';

                return ListTile(
                  title: Text(user['email']?.toString() ?? ''),
                  subtitle: Text(
                    'الاسم: ${user['username'] ?? ''} - الدور: $role',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? Icons.check_circle : Icons.block,
                        color: isActive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => toggleActivation(user),
                        child: Text(isActive ? 'تعطيل' : 'تفعيل'),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
