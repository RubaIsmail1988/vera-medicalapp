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
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(routeLocation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 22, child: Icon(icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
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

    return Scaffold(
      appBar: AppBar(title: const Text("إعدادات الجدولة")),
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
            subtitle: "حدد مدة كل نوع زيارة تقدمه للمرضى.",
            routeLocation: visitTypesRoute,
          ),
        ],
      ),
    );
  }
}
