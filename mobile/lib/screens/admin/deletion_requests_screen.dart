import 'package:flutter/material.dart';

import '/services/admin_user_service.dart';

class DeletionRequestsScreen extends StatefulWidget {
  const DeletionRequestsScreen({super.key});

  @override
  State<DeletionRequestsScreen> createState() => _DeletionRequestsScreenState();
}

class _DeletionRequestsScreenState extends State<DeletionRequestsScreen> {
  final AdminUserService _adminService = AdminUserService();

  late Future<List<Map<String, dynamic>>> _futureRequests;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _futureRequests = _adminService.fetchDeletionRequests();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadRequests();
    });
  }

  /// تنسيق التاريخ من شكل ISO مثل:
  /// 2025-12-08T13:39:45.43754Z
  /// إلى: 08-12-2025 13:39
  String _formatDate(String? iso) {
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
  Map<String, dynamic> _statusInfo(String? status) {
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

  Future<void> _handleApprove(Map<String, dynamic> req) async {
    final int id = req['id'] as int;
    final bool success = await _adminService.approveDeletionRequest(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تمت الموافقة على طلب حذف الحساب.'
              : 'فشل في الموافقة على الطلب.',
        ),
      ),
    );

    if (success) {
      _refresh();
    }
  }

  Future<void> _handleReject(Map<String, dynamic> req) async {
    final int id = req['id'] as int;
    final bool success = await _adminService.rejectDeletionRequest(id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'تم رفض طلب حذف الحساب.' : 'فشل في رفض الطلب.'),
      ),
    );

    if (success) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('طلبات حذف الحساب')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRequests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء تحميل طلبات الحذف.'),
            );
          }

          var requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Text('لا يوجد أي طلبات حذف حساب حالياً.'),
            );
          }

          //  ترتيب الطلبات من الأحدث إلى الأقدم حسب created_at
          requests.sort((a, b) {
            final aDateStr = a['created_at']?.toString();
            final bDateStr = b['created_at']?.toString();
            try {
              final aDate =
                  aDateStr != null ? DateTime.parse(aDateStr) : DateTime(1970);
              final bDate =
                  bDateStr != null ? DateTime.parse(bDateStr) : DateTime(1970);
              return bDate.compareTo(aDate); // الأحدث أولاً
            } catch (_) {
              return 0;
            }
          });

          //  حساب عدد الطلبات لكل مستخدم (حسب user_id أو user.id)
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
            userRequestCounts[userKey] = (userRequestCounts[userKey] ?? 0) + 1;
          }

          final totalCount = requests.length;

          return Column(
            children: [
              //  شريط علوي يوضح إجمالي عدد الطلبات
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: cs.surface.withValues(alpha: 0.8), // ← تعديل هنا
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'إجمالي طلبات حذف الحساب: $totalCount',
                      style: textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];

                      // محاولة قراءة بيانات المستخدم:
                      // إما من كائن user داخلي أو حقول مباشرة
                      Map<String, dynamic>? userMap;
                      if (req['user'] is Map) {
                        userMap = req['user'] as Map<String, dynamic>;
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
                          userMap?['id'] ?? req['user_id'] ?? req['user'];
                      final String userKey = userIdRaw?.toString() ?? '';
                      final int perUserCount =
                          userKey.isNotEmpty
                              ? (userRequestCounts[userKey] ?? 0)
                              : 0;

                      final String status = req['status']?.toString() ?? '';
                      final String createdAt =
                          req['created_at']?.toString() ?? '';
                      final String? updatedAt =
                          req['processed_at']?.toString() ??
                          req['updated_at']?.toString();

                      //  قراءة السبب/الملاحظة
                      final String? reason =
                          req['reason']?.toString() ??
                          req['note']?.toString() ??
                          req['comment']?.toString() ??
                          req['description']?.toString();

                      final statusInfo = _statusInfo(status);
                      final String statusLabel = statusInfo['label'] as String;
                      final Color statusColor = statusInfo['color'] as Color;

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

                      final bool isPending = status.toLowerCase() == 'pending';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // الصف العلوي: الإيميل + حالة الطلب
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.18,
                                      ), // ← تعديل هنا
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // الاسم + الدور + عدد طلبات هذا المستخدم
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withValues(
                                          alpha: 0.18,
                                        ), // ← تعديل هنا
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'طلبات هذا المستخدم: $perUserCount',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.deepOrangeAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (roleLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.secondary.withValues(
                                          alpha: 0.12,
                                        ), // ← تعديل هنا
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

                              // السبب / الملاحظة إن وجد
                              if (reason != null &&
                                  reason.trim().isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        style: textTheme.bodySmall?.copyWith(
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              // تواريخ الطلب
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'تاريخ الطلب: ${_formatDate(createdAt)}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: cs.onSurface,
                                          ),
                                        ),
                                        if (updatedAt != null &&
                                            updatedAt.isNotEmpty)
                                          Text(
                                            'آخر تحديث: ${_formatDate(updatedAt)}',
                                            style: textTheme.bodySmall
                                                ?.copyWith(color: Colors.grey),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              //  أزرار القبول / الرفض (فقط لو الطلب pending)
                              if (isPending)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _handleReject(req),
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
                                      onPressed: () => _handleApprove(req),
                                      icon: const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Colors.greenAccent,
                                      ),
                                      label: const Text(
                                        'موافقة',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
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
    );
  }
}
