// lib/screens/user/patient_home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/models/appointment.dart';
import '/services/appointments_service.dart';
import '/services/auth_service.dart';
import '/services/clinical_service.dart';
import '/utils/api_exception.dart';
import '/utils/ui_helpers.dart';

class PatientHomeScreen extends StatefulWidget {
  final int userId;
  final String token;

  const PatientHomeScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();

  late final AuthService _authService;
  late final ClinicalService _clinicalService;

  String? userName;
  late Future<List<Appointment>> upcomingFuture;
  late Future<List<Map<String, dynamic>>> adviceFuture;

  @override
  void initState() {
    super.initState();

    _authService = AuthService();
    _clinicalService = ClinicalService(authService: _authService);

    // ignore: unawaited_futures
    _loadUserName();

    upcomingFuture = _loadUpcoming();
    adviceFuture = _loadAdvice();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('currentUserName');

    if (!mounted) return;
    setState(() => userName = savedName);
  }

  Future<List<Appointment>> _loadUpcoming() async {
    final items = await appointmentsService.fetchMyAppointments(
      time: 'upcoming',
    );

    items.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final now = DateTime.now();
    final filtered =
        items.where((ap) => ap.dateTime.toLocal().isAfter(now)).toList();

    if (filtered.length <= 3) return filtered;
    return filtered.take(3).toList();
  }

  Future<List<Map<String, dynamic>>> _loadAdvice() async {
    final res = await _clinicalService.fetchPatientAdviceCards(
      patientId: widget.userId,
    );

    if (res.statusCode == 200) {
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      throw const ApiException(500, '{"detail":"Invalid advice response."}');
    }

    if (res.statusCode == 404) {
      return <Map<String, dynamic>>[];
    }

    throw ApiException(res.statusCode, res.body);
  }

  Future<void> _refresh() async {
    setState(() {
      upcomingFuture = _loadUpcoming();
      adviceFuture = _loadAdvice();
    });

    try {
      await Future.wait([upcomingFuture, adviceFuture]);
    } catch (_) {
      // AppFetchStateView / inline error handles it
    }
  }

  String _formatDateYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTimeHm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusLabel(String status) {
    final s = status.trim().toLowerCase();
    switch (s) {
      case 'pending':
        return 'بانتظار التأكيد';
      case 'confirmed':
        return 'مؤكد';
      case 'cancelled':
        return 'ملغي';
      case 'no_show':
        return 'لم يحضر';
      default:
        return status;
    }
  }

  Color _statusColor(ColorScheme cs, String status) {
    final s = status.trim().toLowerCase();
    if (s == 'confirmed') return cs.primary;
    if (s == 'pending') return cs.tertiary;
    if (s == 'cancelled' || s == 'no_show') return cs.error;
    return cs.onSurface.withValues(alpha: 0.70);
  }

  Widget _statusChip(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(cs, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _appointmentCard(BuildContext context, Appointment ap) {
    final cs = Theme.of(context).colorScheme;

    final dtLocal = ap.dateTime.toLocal();
    final date = _formatDateYmd(dtLocal);
    final time = _formatTimeHm(dtLocal);

    final doctor =
        (ap.doctorName ?? '').trim().isNotEmpty
            ? ap.doctorName!.trim()
            : 'الطبيب';

    final typeName =
        (ap.appointmentTypeName ?? '').trim().isNotEmpty
            ? ap.appointmentTypeName!.trim()
            : 'موعد';

    final bool hasOpenOrders = ap.hasOpenOrders == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$date — $time',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusChip(context, ap.status),
            ],
          ),
          const SizedBox(height: 10),
          _kvRow(context, icon: Icons.person, label: 'الطبيب', value: doctor),
          const SizedBox(height: 6),
          _kvRow(
            context,
            icon: Icons.category_rounded,
            label: 'نوع الموعد',
            value: typeName,
          ),
          if (hasOpenOrders) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.tertiary.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: cs.onSurface.withValues(alpha: 0.80),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لديك طلبات (تحليل/صورة) مرتبطة بهذا الموعد تحتاج متابعة.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kvRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.72)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.75),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.88),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Unified Section Header (appointments + advice)
  // ---------------------------------------------------------------------------

  Widget _homeSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Advice UI (calm, no scary numbers)
  // ---------------------------------------------------------------------------

  String _severityLabel(int s) {
    if (s >= 7) return "أولوية عالية";
    if (s >= 4) return "أولوية متوسطة";
    return "إرشاد عام";
  }

  Color _severityColor(ColorScheme cs, int s) {
    if (s >= 7) return cs.error;
    if (s >= 4) return cs.tertiary;
    return cs.primary;
  }

  Widget _adviceCard(BuildContext context, Map<String, dynamic> card) {
    final cs = Theme.of(context).colorScheme;

    final title = (card["title"] ?? "").toString().trim();
    final message = (card["message"] ?? "").toString().trim();
    final severityRaw = card["severity"];
    final int severity =
        (severityRaw is int)
            ? severityRaw
            : int.tryParse(severityRaw?.toString() ?? "") ?? 1;

    final ctaLabel = (card["cta_label"] ?? "").toString().trim();
    final ctaRoute = (card["cta_route"] ?? "").toString().trim();

    final sevColor = _severityColor(cs, severity);
    final sevLabel = _severityLabel(severity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sevLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: sevColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.isNotEmpty ? title : "نصيحة",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty ? message : "-",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: cs.onSurface.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ctaLabel.isNotEmpty && ctaRoute.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  if (!mounted) return;
                  context.go(ctaRoute);
                },
                child: Text(ctaLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final name = (userName ?? '').trim();
    final greeting = name.isNotEmpty ? 'أهلاً بك يا $name' : 'أهلاً بك';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<List<Appointment>>(
        future: upcomingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return AppFetchStateView(
              error: snapshot.error!,
              onRetry: () => setState(() => upcomingFuture = _loadUpcoming()),
            );
          }

          final items = snapshot.data ?? const <Appointment>[];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      greeting,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---------------- Appointments Header (unified style) ----------------
                    _homeSectionHeader(
                      context,
                      title: "المواعيد",
                      subtitle: "أقرب 3 مواعيد قادمة (إن وُجدت).",
                      icon: Icons.calendar_month_outlined,
                    ),
                    const SizedBox(height: 12),

                    if (items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: cs.outline.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          'لا يوجد لديك مواعيد قادمة حالياً.',
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else ...[
                      for (final ap in items) ...[
                        _appointmentCard(context, ap),
                        const SizedBox(height: 12),
                      ],
                    ],

                    const SizedBox(height: 18),

                    // ---------------- Advice Header (unified style) ----------------
                    _homeSectionHeader(
                      context,
                      title: "نصائح مخصصة لك",
                      subtitle: "بناءً على بياناتك الصحية الحالية.",
                      icon: Icons.lightbulb_outline,
                    ),
                    const SizedBox(height: 12),

                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: adviceFuture,
                      builder: (context, adviceSnap) {
                        if (adviceSnap.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.16),
                              ),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }

                        if (adviceSnap.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'تعذّر تحميل النصائح حالياً.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface.withValues(alpha: 0.80),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () {
                                    setState(
                                      () => adviceFuture = _loadAdvice(),
                                    );
                                  },
                                  child: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          );
                        }

                        final cards =
                            adviceSnap.data ?? const <Map<String, dynamic>>[];

                        if (cards.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Text(
                              'لا توجد نصائح حالياً.',
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            for (final c in cards) ...[
                              _adviceCard(context, c),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
