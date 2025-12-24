import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/services/admin_user_service.dart';
import '/utils/ui_helpers.dart';

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
    if (!mounted) return;
    setState(loadAll);
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

    if (normalized == 'active') return isActive;
    if (normalized == 'inactive') return !isActive;

    if (normalized == 'doctor') return role == 'doctor';
    if (normalized == 'patient') return role == 'patient';
    if (normalized == 'admin') return role == 'admin';

    final int deletionCount = user['deletion_requests_count'] as int? ?? 0;
    final String lastStatus =
        user['latest_deletion_status']?.toString().toLowerCase() ?? '';

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

    if (success) {
      showAppSnackBar(
        context,
        isActive ? 'تم تعطيل المستخدم بنجاح.' : 'تم تفعيل المستخدم بنجاح.',
        type: AppSnackBarType.success,
      );
      await refresh();
      return;
    }

    showAppSnackBar(
      context,
      isActive ? 'فشل تعطيل المستخدم.' : 'فشل تفعيل المستخدم.',
      type: AppSnackBarType.error,
    );
  }

  void openDeletionRequests() {
    final cb = widget.onOpenDeletionRequests;
    if (cb != null) {
      cb();
      return;
    }

    // fallback web-safe
    if (!mounted) return;
    context.go('/admin/requests');
  }

  Widget buildUserList(Future<List<Map<String, dynamic>>> future) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredStatus(
            icon: Icons.hourglass_top_rounded,
            title: 'جاري تحميل المستخدمين...',
            showProgress: true,
          );
        }

        if (snapshot.hasError) {
          return _CenteredStatus(
            icon: Icons.error_outline,
            title: 'تعذّر تحميل البيانات.',
            subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
            actionText: 'إعادة المحاولة',
            onAction: refresh,
          );
        }

        final users = snapshot.data ?? [];
        final filteredUsers = users.where(userMatchesQuery).toList();

        if (filteredUsers.isEmpty) {
          return _CenteredStatus(
            icon: searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
            title:
                searchQuery.isEmpty
                    ? 'لا يوجد مستخدمون للعرض.'
                    : 'لا توجد نتائج مطابقة.',
            subtitle:
                searchQuery.isEmpty
                    ? 'اسحب للأسفل للتحديث.'
                    : 'جرّب تعديل كلمة البحث أو اكتب (طبيب/مريض/أدمن).',
          );
        }

        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            itemCount: filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

              return _UserCard(
                email: email,
                username: username,
                roleLabel: roleLabel,
                isActive: isActive,
                deletionCount: deletionCount,
                deletionText: deletionText,
                onToggleActivation: () => toggleActivation(user),
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
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Material(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'طلبات حذف الحساب',
                    icon: const Icon(Icons.delete_forever),
                    onPressed: openDeletionRequests,
                  ),
                ],
              ),
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

        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              buildUserList(futureAll),
              buildUserList(futurePatients),
              buildUserList(futureDoctors),
            ],
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.email,
    required this.username,
    required this.roleLabel,
    required this.isActive,
    required this.deletionCount,
    required this.deletionText,
    required this.onToggleActivation,
  });

  final String email;
  final String username;
  final String roleLabel;
  final bool isActive;
  final int deletionCount;
  final String deletionText;
  final VoidCallback onToggleActivation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final Color statusColor = isActive ? cs.tertiary : cs.error;
    final String statusLabel = isActive ? 'مفعّل' : 'معطّل';

    final Color deletionColor =
        deletionCount > 0 ? cs.secondary : cs.onSurface.withValues(alpha: 0.45);

    return Card(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _Pill(
                  color: statusColor,
                  icon: isActive ? Icons.check_circle : Icons.block,
                  label: statusLabel,
                ),
              ],
            ),
            const SizedBox(height: 10),

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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Deletion requests info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.delete_forever, size: 18, color: deletionColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deletionText,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: deletionColor),
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
                  onPressed: onToggleActivation,
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
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final Future<void> Function()? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: cs.onSurface.withValues(alpha: 0.70)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
              if (showProgress) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () async {
                    await onAction!.call();
                  },
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
