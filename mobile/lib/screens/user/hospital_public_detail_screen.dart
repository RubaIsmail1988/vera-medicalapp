import 'package:flutter/material.dart';

class HospitalPublicDetailScreen extends StatelessWidget {
  final String name;
  final int governorate;
  final String? governorateName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? specialty;
  final String? contactInfo;

  const HospitalPublicDetailScreen({
    super.key,
    required this.name,
    required this.governorate,
    this.governorateName,
    this.address,
    this.latitude,
    this.longitude,
    this.specialty,
    this.contactInfo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل المشفى')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            // الاسم
            Text(
              name,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // المحافظة
            Text(
              'المحافظة: ${governorateName ?? governorate}',
              style: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: 16),

            if (address != null && address!.trim().isNotEmpty) ...[
              Text(
                'العنوان',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address!,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (specialty != null && specialty!.trim().isNotEmpty) ...[
              Text(
                'التخصص',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                specialty!,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (contactInfo != null && contactInfo!.trim().isNotEmpty) ...[
              Text(
                'وسائل التواصل',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                contactInfo!,
                style: textTheme.bodyMedium?.copyWith(color: cs.primary),
              ),
              const SizedBox(height: 16),
            ],

            if (latitude != null && longitude != null) ...[
              Text(
                'الإحداثيات التقريبية',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Lat: $latitude , Lng: $longitude',
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
