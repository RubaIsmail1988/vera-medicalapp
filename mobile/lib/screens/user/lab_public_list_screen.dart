import 'package:flutter/material.dart';

import '/models/lab.dart';
import '/services/lab_service.dart';
import 'lab_public_detail_screen.dart';

class LabPublicListScreen extends StatefulWidget {
  const LabPublicListScreen({super.key});

  @override
  State<LabPublicListScreen> createState() => _LabPublicListScreenState();
}

class _LabPublicListScreenState extends State<LabPublicListScreen> {
  final LabService labService = LabService();
  late Future<List<Lab>> futureLabs;

  @override
  void initState() {
    super.initState();
    // إذا كان اسم الدالة في LabService مختلفاً (مثلاً getLabs)، عدّلي السطر التالي فقط:
    futureLabs = labService.fetchLabs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة المخابر')),
      body: FutureBuilder<List<Lab>>(
        future: futureLabs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء جلب قائمة المخابر.'),
            );
          }

          final labs = snapshot.data ?? [];

          if (labs.isEmpty) {
            return const Center(child: Text('لا توجد مخابر متاحة حالياً.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: labs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final lab = labs[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(lab.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المحافظة (ID): ${lab.governorate}'),
                      if (lab.specialty != null &&
                          lab.specialty!.trim().isNotEmpty)
                        Text('التخصص: ${lab.specialty}'),
                      if (lab.contactInfo != null &&
                          lab.contactInfo!.trim().isNotEmpty)
                        Text('الاتصال: ${lab.contactInfo}'),
                    ],
                  ),
                  // عرض تفاصيل فقط عند الضغط (بدون CRUD)
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => LabPublicDetailScreen(
                              name: lab.name,
                              governorate: lab.governorate,
                              address: lab.address,
                              latitude: lab.latitude,
                              longitude: lab.longitude,
                              specialty: lab.specialty,
                              contactInfo: lab.contactInfo,
                            ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
