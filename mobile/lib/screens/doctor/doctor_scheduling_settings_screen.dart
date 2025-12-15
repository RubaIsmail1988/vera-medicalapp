import 'package:flutter/material.dart';

import 'doctor_availability_screen.dart';
import 'doctor_visit_types_screen.dart';

class DoctorSchedulingSettingsScreen extends StatelessWidget {
  const DoctorSchedulingSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget buildCard({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Card(
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
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
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
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

    return Scaffold(
      appBar: AppBar(title: const Text("إعدادات الجدولة")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          buildCard(
            icon: Icons.schedule,
            title: "أوقات دوام الطبيب",
            subtitle: "حدد يوم العمل وساعات الدوام (فترة واحدة لكل يوم).",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DoctorAvailabilityScreen(),
                ),
              );
            },
          ),
          buildCard(
            icon: Icons.timer_outlined,
            title: "مدد أنواع الزيارة",
            subtitle: "حدد مدة كل نوع زيارة تقدمه للمرضى.",
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DoctorVisitTypesScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
