import 'dart:async';

import 'package:flutter/material.dart';

import '/services/admin_user_service.dart';
import '/screens/admin/deletion_requests_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key, this.onOpenDeletionRequests});

  final VoidCallback? onOpenDeletionRequests;

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with SingleTickerProviderStateMixin {
  final AdminUserService adminService = AdminUserService();

  late TabController tabController;

  late Future<List<Map<String, dynamic>>> futureAll;
  late Future<List<Map<String, dynamic>>> futurePatients;
  late Future<List<Map<String, dynamic>>> futureDoctors;

  // Search
  final TextEditingController searchController = TextEditingController();
  Timer? searchDebounce;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
    loadAll();
  }

  void loadAll() {
    futureAll = adminService.fetchAllUsers();
    futurePatients = adminService.fetchPatients();
    futureDoctors = adminService.fetchDoctors();
  }

  Future<void> refresh() async {
    setState(() {
      loadAll();
    });
  }

  void onSearchChanged(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        searchQuery = value.trim().toLowerCase();
      });
    });
  }

  String normalizeQuery(String q) {
    var v = q.trim().toLowerCase();

    // تطبيع عربي بسيط
    v = v.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');

    // الحالة
    v = v.replaceAll('مفعل', 'active');
    v = v.replaceAll('مفعّل', 'active');
    v = v.replaceAll('فعال', 'active');
    v = v.replaceAll('نشط', 'active');

    v = v.replaceAll('معطل', 'inactive');
    v = v.replaceAll('معطّل', 'inactive');
    v = v.replaceAll('غير مفعل', 'inactive');
    v = v.replaceAll('غير مفعّل', 'inactive');
    v = v.replaceAll('محظور', 'inactive');

    // الأدوار
    v = v.replaceAll('ادمن', 'admin');
    v = v.replaceAll('أدمن', 'admin');
    v = v.replaceAll('مسؤول', 'admin');

    v = v.replaceAll('طبيب', 'doctor');
    v = v.replaceAll('دكتور', 'doctor');

    v = v.replaceAll('مريض', 'patient');

    return v;
  }

  bool userMatchesQuery(Map<String, dynamic> user) {
    if (searchQuery.isEmpty) return true;

    final normalized = normalizeQuery(searchQuery);

    final String email = user['email']?.toString().toLowerCase() ?? '';
    final String username = user['username']?.toString().toLowerCase() ?? '';
    final String role = user['role']?.toString().toLowerCase() ?? '';
    final bool isActive = user['is_active'] as bool? ?? false;

    // 1) معالجة الحالة بشكل صارم لتجنب مشكلة inactive يحتوي active
    if (normalized == 'active') return isActive;
    if (normalized == 'inactive') return !isActive;

    // 2) (اختياري) دعم الدور فقط إذا رغبت (مفيد غالبًا في تبويب "الكل")
    if (normalized == 'doctor') return role == 'doctor';
    if (normalized == 'patient') return role == 'patient';
    if (normalized == 'admin') return role == 'admin';

    final int deletionCount = user['deletion_requests_count'] as int? ?? 0;
    final String lastStatus =
        user['latest_deletion_status']?.toString().toLowerCase() ?? '';

    // بحث نصي عام (email/username/حالة طلبات الحذف)
    final String haystack = [
      email,
      username,
      '$deletionCount',
      lastStatus,
    ].join(' ');

    return haystack.contains(normalized);
  }

  Future<void> toggleActivation(Map<String, dynamic> user) async {
    final int userId = user['id'] as int;
    final bool isActive = user['is_active'] as bool? ?? false;

    bool success;
    if (isActive) {
      success = await adminService.deactivateUser(userId);
    } else {
      success = await adminService.activateUser(userId);
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
      await refresh();
    }
  }

  Widget buildUserList(Future<List<Map<String, dynamic>>> future) {
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
        final filteredUsers = users.where(userMatchesQuery).toList();

        if (filteredUsers.isEmpty) {
          return Center(
            child: Text(
              searchQuery.isEmpty
                  ? 'لا يوجد بيانات.'
                  : 'لا توجد نتائج مطابقة للبحث.',
            ),
          );
        }

        final cs = Theme.of(context).colorScheme;

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];

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
                      // Email + Activation status
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

                      // Name + Role
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

                      // Deletion requests info
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

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => toggleActivation(user),
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
    searchDebounce?.cancel();
    searchController.dispose();
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'بحث (بريد، اسم، دور، حالة...)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        searchQuery.isEmpty
                            ? null
                            : IconButton(
                              tooltip: 'مسح البحث',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              TabBar(
                controller: tabController,
                tabs: const [
                  Tab(text: 'الكل'),
                  Tab(text: 'المرضى'),
                  Tab(text: 'الأطباء'),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'طلبات حذف الحساب',
            onPressed: () {
              final cb = widget.onOpenDeletionRequests;
              if (cb != null) {
                cb();
                return;
              }

              // fallback إذا فُتحت الشاشة خارج الـ shell لأي سبب
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
        controller: tabController,
        children: [
          buildUserList(futureAll),
          buildUserList(futurePatients),
          buildUserList(futureDoctors),
        ],
      ),
    );
  }
}
