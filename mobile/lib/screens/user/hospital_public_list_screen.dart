import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/services/hospital_service.dart';
import 'hospital_public_detail_screen.dart';

class HospitalPublicListScreen extends StatefulWidget {
  const HospitalPublicListScreen({super.key});

  @override
  State<HospitalPublicListScreen> createState() =>
      _HospitalPublicListScreenState();
}

class _HospitalPublicListScreenState extends State<HospitalPublicListScreen> {
  final HospitalService hospitalService = HospitalService();
  late Future<List<Hospital>> futureHospitals;

  @override
  void initState() {
    super.initState();
    futureHospitals = hospitalService.fetchHospitals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قائمة المشافي')),
      body: FutureBuilder<List<Hospital>>(
        future: futureHospitals,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('حدث خطأ أثناء جلب قائمة المشافي.'),
            );
          }

          final hospitals = snapshot.data ?? [];

          if (hospitals.isEmpty) {
            return const Center(child: Text('لا توجد مشافي متاحة حالياً.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hospitals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final hospital = hospitals[index];

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(hospital.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المحافظة (ID): ${hospital.governorate}'),
                      if (hospital.specialty != null &&
                          hospital.specialty!.trim().isNotEmpty)
                        Text('التخصص: ${hospital.specialty}'),
                      if (hospital.contactInfo != null &&
                          hospital.contactInfo!.trim().isNotEmpty)
                        Text('الاتصال: ${hospital.contactInfo}'),
                    ],
                  ),
                  // عرض تفاصيل فقط عند الضغط (بدون CRUD)
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => HospitalPublicDetailScreen(
                              name: hospital.name,
                              governorate: hospital.governorate,
                              address: hospital.address,
                              latitude: hospital.latitude,
                              longitude: hospital.longitude,
                              specialty: hospital.specialty,
                              contactInfo: hospital.contactInfo,
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
