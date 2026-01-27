import 'package:flutter/material.dart';

import '/analytics/doctor_home_analytics.dart';

// BottomSheet content (public widget)
class DoctorAnalyticsSheet extends StatelessWidget {
  final DoctorAnalytics analytics;

  const DoctorAnalyticsSheet({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    String formatDateYmd(DateTime dt) {
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }

    final from = formatDateYmd(analytics.fromLocal);
    final to = formatDateYmd(analytics.toLocal);

    Widget metricCard({
      required String title,
      required String value,
      required IconData icon,
    }) {
      return Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.onSurface.withValues(alpha: 0.78)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تحليلات الطبيب',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          'آخر 30 يوم ($from → $to)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.70),
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 14),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            metricCard(
              title: 'إجمالي المواعيد',
              value: analytics.totalAppointments.toString(),
              icon: Icons.event_note_rounded,
            ),
            metricCard(
              title: 'نسبة الإلغاء',
              value: '${analytics.cancellationRatePct}%',
              icon: Icons.cancel_schedule_send_rounded,
            ),
            metricCard(
              title: 'نسبة عدم الحضور',
              value: '${analytics.noShowRatePct}%',
              icon: Icons.person_off_rounded,
            ),
          ],
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'أوقات الذروة حسب الساعة',
                textAlign: TextAlign.right,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              PeakHoursBarChart(analytics: analytics),
            ],
          ),
        ),
      ],
    );
  }
}

class PeakHoursBarChart extends StatelessWidget {
  final DoctorAnalytics analytics;

  const PeakHoursBarChart({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final maxV = analytics.maxHourCount;
    if (analytics.peakHoursCounts.isEmpty || maxV <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'لا توجد بيانات كافية لعرض الرسم.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.72),
          ),
        ),
      );
    }

    final hours = analytics.sortedHoursAsc;

    return SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (ctx, c) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in hours) ...[
                    _HourBar(
                      hour: h,
                      value: analytics.countAtHour(h),
                      maxValue: maxV,
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  final int hour;
  final int value;
  final int maxValue;

  const _HourBar({
    required this.hour,
    required this.value,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pct = (maxValue <= 0) ? 0.0 : (value / maxValue).clamp(0.0, 1.0);

    final barMaxH = 140.0;
    final barH = (barMaxH * pct);

    return SizedBox(
      width: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: barH < 3 ? 3 : barH,
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hour.toString(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.70),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
