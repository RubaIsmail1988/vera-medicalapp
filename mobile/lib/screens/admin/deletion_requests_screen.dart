import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/admin_user_service.dart';

class DeletionRequestsScreen extends StatefulWidget {
  const DeletionRequestsScreen({super.key});

  @override
  State<DeletionRequestsScreen> createState() => _DeletionRequestsScreenState();
}

class _DeletionRequestsScreenState extends State<DeletionRequestsScreen> {
  static const String _prefsSearchKey = 'admin_deletion_requests_search_query';

  final AdminUserService adminService = AdminUserService();
  late Future<List<Map<String, dynamic>>> futureRequests;

  // Search
  final TextEditingController searchController = TextEditingController();
  Timer? searchDebounce;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadSearchState();
    loadRequests();
  }

  void loadRequests() {
    futureRequests = adminService.fetchDeletionRequests();
  }

  Future<void> refresh() async {
    setState(() {
      loadRequests();
    });
  }

  Future<void> loadSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsSearchKey) ?? '';

    if (!mounted) return;

    setState(() {
      searchQuery = saved.trim().toLowerCase();
      searchController.text = saved;
    });
  }

  Future<void> saveSearchState(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSearchKey, value);
  }

  void onSearchChanged(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      final v = value.trim();

      setState(() {
        searchQuery = v.toLowerCase();
      });

      await saveSearchState(v);
    });
  }

  void showAppSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// تنسيق التاريخ من شكل ISO مثل:
  /// 2025-12-08T13:39:45.43754Z
  /// إلى: 08-12-2025 13:39
  String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso);
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final y = dt.year.toString();
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$d-$m-$y  $h:$min';
    } catch (_) {
      return iso;
    }
  }

  /// تحويل status إلى نص عربي + لون
  Map<String, dynamic> statusInfo(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s == 'pending') {
      return {'label': 'قيد المراجعة', 'color': Colors.orangeAccent};
    } else if (s == 'approved') {
      return {'label': 'مقبول', 'color': Colors.greenAccent};
    } else if (s == 'rejected') {
      return {'label': 'مرفوض', 'color': Colors.redAccent};
    }
    return {'label': status ?? 'غير معروف', 'color': Colors.grey};
  }

  bool requestMatchesQuery(Map<String, dynamic> req) {
    if (searchQuery.isEmpty) return true;

    Map<String, dynamic>? userMap;
    if (req['user'] is Map) {
      userMap = req['user'] as Map<String, dynamic>;
    }

    final String email =
        userMap?['email']?.toString() ?? req['user_email']?.toString() ?? '';
    final String username =
        userMap?['username']?.toString() ??
        req['user_username']?.toString() ??
        '';
    final String role =
        userMap?['role']?.toString() ?? req['user_role']?.toString() ?? '';

    final String status = req['status']?.toString() ?? '';

    final String? reason =
        req['reason']?.toString() ??
        req['note']?.toString() ??
        req['comment']?.toString() ??
        req['description']?.toString();

    final haystack =
        [email, username, role, status, reason ?? ''].join(' ').toLowerCase();

    return haystack.contains(searchQuery);
  }

  Future<void> handleApprove(Map<String, dynamic> req) async {
    final int id = req['id'] as int;
    final bool success = await adminService.approveDeletionRequest(id);

    if (!mounted) return;

    showAppSnackBar(
      success
          ? 'تمت الموافقة على طلب حذف الحساب.'
          : 'فشل في الموافقة على الطلب.',
    );

    if (success) {
      await refresh();
    }
  }

  Future<void> handleReject(Map<String, dynamic> req) async {
    final int id = req['id'] as int;
    final bool success = await adminService.rejectDeletionRequest(id);

    if (!mounted) return;

    showAppSnackBar(success ? 'تم رفض طلب حذف الحساب.' : 'فشل في رفض الطلب.');

    if (success) {
      await refresh();
    }
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات حذف الحساب')),
      body: Column(
        children: [
          // Search UI
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'بحث (email، اسم، role، status، سبب...)',
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

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: futureRequests,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('حدث خطأ أثناء تحميل طلبات الحذف.'),
                  );
                }

                final requestsAll = snapshot.data ?? [];

                if (requestsAll.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد أي طلبات حذف حساب حالياً.'),
                  );
                }

                // ترتيب من الأحدث إلى الأقدم
                final requests = [...requestsAll];
                requests.sort((a, b) {
                  final aDateStr = a['created_at']?.toString();
                  final bDateStr = b['created_at']?.toString();
                  try {
                    final aDate =
                        aDateStr != null
                            ? DateTime.parse(aDateStr)
                            : DateTime(1970);
                    final bDate =
                        bDateStr != null
                            ? DateTime.parse(bDateStr)
                            : DateTime(1970);
                    return bDate.compareTo(aDate);
                  } catch (_) {
                    return 0;
                  }
                });

                // counts لكل مستخدم
                final Map<String, int> userRequestCounts = {};
                for (final req in requests) {
                  Map<String, dynamic>? userMap;
                  if (req['user'] is Map) {
                    userMap = req['user'] as Map<String, dynamic>;
                  }
                  final dynamic userIdRaw =
                      userMap?['id'] ?? req['user_id'] ?? req['user'];
                  final String userKey = userIdRaw?.toString() ?? '';
                  if (userKey.isEmpty) continue;
                  userRequestCounts[userKey] =
                      (userRequestCounts[userKey] ?? 0) + 1;
                }

                final filtered = requests.where(requestMatchesQuery).toList();

                //  إجمالي الطلبات (إجمالي + نتائج البحث)
                final int totalCount = requests.length;
                final int shownCount = filtered.length;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: cs.surface.withValues(alpha: 0.8),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              searchQuery.isEmpty
                                  ? 'إجمالي طلبات حذف الحساب: $totalCount'
                                  : 'النتائج: $shownCount من أصل $totalCount',
                              style: textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child:
                          filtered.isEmpty
                              ? const Center(
                                child: Text('لا توجد نتائج مطابقة للبحث.'),
                              )
                              : RefreshIndicator(
                                onRefresh: refresh,
                                child: ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final req = filtered[index];

                                    Map<String, dynamic>? userMap;
                                    if (req['user'] is Map) {
                                      userMap =
                                          req['user'] as Map<String, dynamic>;
                                    }

                                    final String email =
                                        userMap?['email']?.toString() ??
                                        req['user_email']?.toString() ??
                                        '';
                                    final String username =
                                        userMap?['username']?.toString() ??
                                        req['user_username']?.toString() ??
                                        '';
                                    final String role =
                                        userMap?['role']?.toString() ??
                                        req['user_role']?.toString() ??
                                        '';

                                    final dynamic userIdRaw =
                                        userMap?['id'] ??
                                        req['user_id'] ??
                                        req['user'];
                                    final String userKey =
                                        userIdRaw?.toString() ?? '';
                                    final int perUserCount =
                                        userKey.isNotEmpty
                                            ? (userRequestCounts[userKey] ?? 0)
                                            : 0;

                                    final String status =
                                        req['status']?.toString() ?? '';
                                    final String createdAt =
                                        req['created_at']?.toString() ?? '';
                                    final String? updatedAt =
                                        req['processed_at']?.toString() ??
                                        req['updated_at']?.toString();

                                    final String? reason =
                                        req['reason']?.toString() ??
                                        req['note']?.toString() ??
                                        req['comment']?.toString() ??
                                        req['description']?.toString();

                                    final info = statusInfo(status);
                                    final String statusLabel =
                                        info['label'] as String;
                                    final Color statusColor =
                                        info['color'] as Color;

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

                                    final bool isPending =
                                        status.toLowerCase() == 'pending';

                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    email,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withValues(
                                                          alpha: 0.18,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'الاسم: $username',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: cs.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (perUserCount > 0)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.deepOrange
                                                          .withValues(
                                                            alpha: 0.18,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'طلبات هذا المستخدم: $perUserCount',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .deepOrangeAccent,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                if (roleLabel.isNotEmpty)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: cs.secondary
                                                          .withValues(
                                                            alpha: 0.12,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      roleLabel,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: cs.secondary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (reason != null &&
                                                reason.trim().isNotEmpty) ...[
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.notes,
                                                    size: 18,
                                                    color: Colors.amber,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'السبب: $reason',
                                                      style: textTheme.bodySmall
                                                          ?.copyWith(
                                                            color: cs.onSurface,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.schedule,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'تاريخ الطلب: ${formatDate(createdAt)}',
                                                        style: textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color:
                                                                  cs.onSurface,
                                                            ),
                                                      ),
                                                      if (updatedAt != null &&
                                                          updatedAt.isNotEmpty)
                                                        Text(
                                                          'آخر تحديث: ${formatDate(updatedAt)}',
                                                          style: textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            if (isPending)
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed:
                                                        () => handleReject(req),
                                                    icon: const Icon(
                                                      Icons.close,
                                                      size: 18,
                                                      color: Colors.redAccent,
                                                    ),
                                                    label: const Text(
                                                      'رفض',
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  TextButton.icon(
                                                    onPressed:
                                                        () =>
                                                            handleApprove(req),
                                                    icon: const Icon(
                                                      Icons.check,
                                                      size: 18,
                                                      color: Colors.greenAccent,
                                                    ),
                                                    label: const Text(
                                                      'موافقة',
                                                      style: TextStyle(
                                                        color:
                                                            Colors.greenAccent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
