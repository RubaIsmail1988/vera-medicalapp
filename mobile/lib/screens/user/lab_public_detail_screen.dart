import 'package:flutter/material.dart';

class LabPublicDetailScreen extends StatelessWidget {
  final String name;
  final int governorate;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? specialty;
  final String? contactInfo;

  const LabPublicDetailScreen({
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المخبر')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            // الاسم
            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // المحافظة
            Text(
              'المحافظة (ID): $governorate',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // العنوان
            if (address != null && address!.trim().isNotEmpty) ...[
              const Text(
                'العنوان:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(address!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],

            // التخصص
            if (specialty != null && specialty!.trim().isNotEmpty) ...[
              const Text(
                'التخصص:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(specialty!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
            ],

            // وسائل التواصل
            if (contactInfo != null && contactInfo!.trim().isNotEmpty) ...[
              const Text(
                'وسائل التواصل:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                contactInfo!,
                style: TextStyle(fontSize: 14, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
            ],

            // الإحداثيات
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
