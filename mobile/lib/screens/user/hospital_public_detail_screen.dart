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

  bool _hasText(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final governorateLabel =
        _hasText(governorateName)
            ? governorateName!.trim()
            : governorate.toString();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('معلومات المشفى'), centerTitle: true),
        body: SelectionArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                name,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                governorateLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),

              const SizedBox(height: 20),
              Divider(color: cs.onSurface.withValues(alpha: 0.10)),
              const SizedBox(height: 20),

              _InfoSection(
                icon: Icons.location_city,
                label: 'المحافظة',
                value: governorateLabel,
              ),

              if (_hasText(address)) ...[
                const SizedBox(height: 16),
                _InfoSection(
                  icon: Icons.place_outlined,
                  label: 'العنوان',
                  value: address!.trim(),
                ),
              ],

              if (_hasText(specialty)) ...[
                const SizedBox(height: 16),
                _InfoSection(
                  icon: Icons.medical_services_outlined,
                  label: 'التخصص',
                  value: specialty!.trim(),
                ),
              ],

              if (_hasText(contactInfo)) ...[
                const SizedBox(height: 16),
                _InfoSection(
                  icon: Icons.phone_outlined,
                  label: 'وسائل التواصل',
                  value: contactInfo!.trim(),
                  valueColor: cs.primary,
                ),
              ],

              if (latitude != null && longitude != null) ...[
                const SizedBox(height: 16),
                _InfoSection(
                  icon: Icons.map_outlined,
                  label: 'الموقع التقريبي',
                  value:
                      '${latitude!.toStringAsFixed(4)} ، ${longitude!.toStringAsFixed(4)}',
                  valueStyle: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  const _InfoSection({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.65)),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style:
              valueStyle ??
              textTheme.bodyLarge?.copyWith(
                height: 1.5,
                color: valueColor ?? cs.onSurface.withValues(alpha: 0.90),
              ),
        ),
      ],
    );
  }
}
