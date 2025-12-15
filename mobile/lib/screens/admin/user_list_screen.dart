import 'package:flutter/material.dart';

import '/services/admin_user_service.dart';
import '/screens/admin/deletion_requests_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with SingleTickerProviderStateMixin {
  final AdminUserService _adminService = AdminUserService();

  late TabController _tabController;

  late Future<List<Map<String, dynamic>>> _futureAll;
  late Future<List<Map<String, dynamic>>> _futurePatients;
  late Future<List<Map<String, dynamic>>> _futureDoctors;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  void _loadAll() {
    _futureAll = _adminService.fetchAllUsers();
    _futurePatients = _adminService.fetchPatients();
    _futureDoctors = _adminService.fetchDoctors();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadAll();
    });
  }

  Future<void> _toggleActivation(Map<String, dynamic> user) async {
    final int userId = user['id'] as int;
    final bool isActive = user['is_active'] as bool? ?? false;

    bool success;
    if (isActive) {
      success = await _adminService.deactivateUser(userId);
    } else {
      success = await _adminService.activateUser(userId);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isActive
                  ? 'تم تعطيل المستخدم بنجاح.'
                  : 'تم تفعيل المستخدم بنجاح.')
              : (isActive ? 'فشل تعطيل المستخدم.' : 'فشل تفعيل المستخدم.'),
        ),
      ),
    );

    if (success) {
      _refresh();
    }
  }

  Widget _buildUserList(Future<List<Map<String, dynamic>>> future) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('حدث خطأ أثناء تحميل البيانات.'));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('لا يوجد بيانات.'));
        }

        final cs = Theme.of(context).colorScheme;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              final String email = user['email']?.toString() ?? '';
              final String username = user['username']?.toString() ?? '';
              final String role = user['role']?.toString() ?? '';
              final bool isActive = user['is_active'] as bool? ?? false;

              final int deletionCount =
                  user['deletion_requests_count'] as int? ?? 0;
              final String? lastStatus =
                  user['latest_deletion_status']?.toString();

              String deletionText;
              if (deletionCount == 0) {
                deletionText = 'لا يوجد طلبات حذف حساب.';
              } else {
                deletionText =
                    'طلبات حذف الحساب: $deletionCount'
                    '${lastStatus != null ? ' | آخر حالة: $lastStatus' : ''}';
              }

              final Color statusColor =
                  isActive ? Colors.greenAccent : Colors.redAccent;
              final String statusLabel = isActive ? 'مفعّل' : 'معطّل';

              String roleLabel;
              switch (role) {
                case 'admin':
                  roleLabel = 'أدمن';
                  break;
                case 'doctor':
                  roleLabel = 'طبيب';
                  break;
                case 'patient':
                  roleLabel = 'مريض';
                  break;
                default:
                  roleLabel = role;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // الصف العلوي: الإيميل + حالة التفعيل
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              email,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              // كان: statusColor.withOpacity(0.15)
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.block,
                                  size: 16,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // الاسم + الدور
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'الاسم: $username',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              // كان: cs.secondary.withOpacity(0.12)
                              color: cs.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // معلومات طلبات الحذف
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.delete_forever,
                            size: 18,
                            color:
                                deletionCount > 0
                                    ? Colors.orangeAccent
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              deletionText,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color:
                                    deletionCount > 0
                                        ? Colors.orangeAccent
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // أزرار الإجراء (تفعيل/تعطيل)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleActivation(user),
                            icon: Icon(
                              isActive ? Icons.lock_person : Icons.lock_open,
                              size: 18,
                            ),
                            label: Text(isActive ? 'تعطيل' : 'تفعيل'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'المرضى'),
            Tab(text: 'الأطباء'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'طلبات حذف الحساب',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeletionRequestsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserList(_futureAll),
          _buildUserList(_futurePatients),
          _buildUserList(_futureDoctors),
        ],
      ),
    );
  }
}
