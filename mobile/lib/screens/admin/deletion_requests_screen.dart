import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/services/admin_user_service.dart';
import '/utils/ui_helpers.dart';

class DeletionRequestsScreen extends StatefulWidget {
  const DeletionRequestsScreen({super.key});

  @override
  State<DeletionRequestsScreen> createState() => _DeletionRequestsScreenState();
}

class _DeletionRequestsScreenState extends State<DeletionRequestsScreen> {
  static const String prefsSearchKey = 'admin_deletion_requests_search_query';

  final AdminUserService adminService = AdminUserService();
  late Future<List<Map<String, dynamic>>> futureRequests;

  // Search
  final TextEditingController searchController = TextEditingController();
  Timer? searchDebounce;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadRequests();
    loadSearchState();
  }

  void loadRequests() {
    futureRequests = adminService.fetchDeletionRequests();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(loadRequests);
  }

  Future<void> loadSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefsSearchKey) ?? '';

    if (!mounted) return;

    setState(() {
      searchQuery = saved.trim().toLowerCase();
      searchController.text = saved;
    });
  }

  Future<void> saveSearchState(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsSearchKey, value);
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

  /// 2025-12-08T13:39:45.43754Z -> 08-12-2025 13:39
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

    final confirmed = await showConfirmDialog(
      context,
      title: 'تأكيد الموافقة',
      message: 'هل أنت متأكد من الموافقة على طلب حذف الحساب؟',
      confirmText: 'موافقة',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!confirmed) return;

    final bool success = await adminService.approveDeletionRequest(id);

    if (!mounted) return;

    if (success) {
      showAppSnackBar(
        context,
        'تمت الموافقة على طلب حذف الحساب.',
        type: AppSnackBarType.success,
      );
      await refresh();
      return;
    }

    showAppSnackBar(
      context,
      'فشل في الموافقة على الطلب.',
      type: AppSnackBarType.error,
    );
  }

  Future<void> handleReject(Map<String, dynamic> req) async {
    final int id = req['id'] as int;

    final confirmed = await showConfirmDialog(
      context,
      title: 'تأكيد الرفض',
      message: 'هل أنت متأكد من رفض طلب حذف الحساب؟',
      confirmText: 'رفض',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!confirmed) return;

    final bool success = await adminService.rejectDeletionRequest(id);

    if (!mounted) return;

    if (success) {
      showAppSnackBar(
        context,
        'تم رفض طلب حذف الحساب.',
        type: AppSnackBarType.success,
      );
      await refresh();
      return;
    }

    showAppSnackBar(context, 'فشل في رفض الطلب.', type: AppSnackBarType.error);
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

    // ملاحظة: بدون Scaffold لأننا داخل AdminShell
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Material(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(10),
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
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: futureRequests,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _CenteredStatus(
                  icon: Icons.hourglass_top_rounded,
                  title: 'جاري تحميل طلبات الحذف...',
                  showProgress: true,
                );
              }

              if (snapshot.hasError) {
                return _CenteredStatus(
                  icon: Icons.error_outline,
                  title: 'تعذّر تحميل طلبات الحذف.',
                  subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
                  actionText: 'إعادة المحاولة',
                  onAction: refresh,
                );
              }

              final requestsAll = snapshot.data ?? [];

              if (requestsAll.isEmpty) {
                return const _CenteredStatus(
                  icon: Icons.delete_forever_outlined,
                  title: 'لا يوجد أي طلبات حذف حساب حاليًا.',
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

              final int totalCount = requests.length;
              final int shownCount = filtered.length;

              return Column(
                children: [
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: cs.onSurface.withValues(alpha: 0.78),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              searchQuery.isEmpty
                                  ? 'إجمالي طلبات حذف الحساب: $totalCount'
                                  : 'النتائج: $shownCount من أصل $totalCount',
                              style: textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const _CenteredStatus(
                              icon: Icons.search_off,
                              title: 'لا توجد نتائج مطابقة للبحث.',
                              subtitle: 'جرّب تعديل كلمة البحث.',
                            )
                            : RefreshIndicator(
                              onRefresh: refresh,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 8),
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
                                                  style: textTheme.titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              _Chip(
                                                label: statusLabel,
                                                color: statusColor,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'الاسم: $username',
                                                  style: textTheme.bodyMedium
                                                      ?.copyWith(
                                                        color: cs.onSurface,
                                                      ),
                                                ),
                                              ),
                                              if (perUserCount > 1)
                                                const _Chip(
                                                  label: 'طلبات متعددة',
                                                  color:
                                                      Colors.deepOrangeAccent,
                                                ),
                                              if (roleLabel.isNotEmpty) ...[
                                                const SizedBox(width: 6),
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
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          if (reason != null &&
                                              reason.trim().isNotEmpty) ...[
                                            _InfoRow(
                                              icon: Icons.notes_outlined,
                                              iconColor: Colors.amber,
                                              text: 'السبب: $reason',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          _InfoRow(
                                            icon: Icons.schedule,
                                            iconColor: cs.onSurface.withValues(
                                              alpha: 0.55,
                                            ),
                                            text:
                                                'تاريخ الطلب: ${formatDate(createdAt)}',
                                          ),
                                          if (updatedAt != null &&
                                              updatedAt.isNotEmpty)
                                            _InfoRow(
                                              icon: Icons.update,
                                              iconColor: cs.onSurface
                                                  .withValues(alpha: 0.45),
                                              text:
                                                  'آخر تحديث: ${formatDate(updatedAt)}',
                                              dimmed: true,
                                            ),
                                          if (isPending) ...[
                                            const SizedBox(height: 10),
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
                                                  ),
                                                  label: const Text('رفض'),
                                                  style: ButtonStyle(
                                                    foregroundColor:
                                                        WidgetStatePropertyAll<
                                                          Color
                                                        >(cs.error),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed:
                                                      () => handleApprove(req),
                                                  icon: const Icon(
                                                    Icons.check,
                                                    size: 18,
                                                  ),
                                                  label: const Text('موافقة'),
                                                  style: ButtonStyle(
                                                    foregroundColor:
                                                        const WidgetStatePropertyAll<
                                                          Color
                                                        >(Colors.greenAccent),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.dimmed = false,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    dimmed
                        ? cs.onSurface.withValues(alpha: 0.55)
                        : cs.onSurface.withValues(alpha: 0.78),
                height: 1.2,
              ),
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
