import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DoctorSchedulingSettingsScreen extends StatelessWidget {
  const DoctorSchedulingSettingsScreen({super.key});

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String routeLocation,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(routeLocation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // الأيقونة على اليمين
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),

              // النصوص (محاذاة يمين)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // سهم للأمام ضمن RTL
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const availabilityRoute = '/app/doctor/scheduling/availability';
    const visitTypesRoute = '/app/doctor/scheduling/visit-types';
    const absencesRoute = '/app/doctor/scheduling/absences';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("إعدادات الجدولة"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/app/account'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildCard(
              context: context,
              icon: Icons.schedule,
              title: "أوقات دوام الطبيب",
              subtitle: "حدد يوم العمل وساعات الدوام (فترة واحدة لكل يوم).",
              routeLocation: availabilityRoute,
            ),
            _buildCard(
              context: context,
              icon: Icons.timer_outlined,
              title: "مدد أنواع الزيارة",
              subtitle: "حدد مدة كل نوع زيارة تقدمه للمرضى",
              routeLocation: visitTypesRoute,
            ),
            _buildCard(
              context: context,
              icon: Icons.event_busy,
              title: "غيابات الطبيب",
              subtitle:
                  "إدارة فترات عدم التوفر (استراحة، طارئ) وتأثيرها على الحجز",
              routeLocation: absencesRoute,
            ),
          ],
        ),
      ),
    );
  }
}
