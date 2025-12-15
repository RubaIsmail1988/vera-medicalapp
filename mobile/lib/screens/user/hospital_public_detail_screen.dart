import 'package:flutter/material.dart';

class HospitalPublicDetailScreen extends StatelessWidget {
  final String name;
  final int governorate;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? specialty;
  final String? contactInfo;

  const HospitalPublicDetailScreen({
    super.key,
    required this.name,
    required this.governorate,
    this.address,
    this.latitude,
    this.longitude,
    this.specialty,
    this.contactInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشفى')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            Text(
              'المحافظة (ID): $governorate',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            if (address != null && address!.trim().isNotEmpty) ...[
              const Text(
                'العنوان:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(address!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],

            if (specialty != null && specialty!.trim().isNotEmpty) ...[
              const Text(
                'التخصص:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(specialty!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],

            if (contactInfo != null && contactInfo!.trim().isNotEmpty) ...[
              const Text(
                'وسائل التواصل:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                contactInfo!,
                style: TextStyle(fontSize: 14, color: cs.primary),
              ),
              const SizedBox(height: 12),
            ],

            if (latitude != null && longitude != null) ...[
              const Text(
                'الإحداثيات (تقريبية):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                'Lat: $latitude, Lng: $longitude',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
