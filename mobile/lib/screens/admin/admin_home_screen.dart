import 'package:flutter/material.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.onNavigateToTab});

  final void Function(int index) onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminActionCard(
          title: "إدارة المستخدمين",
          subtitle: "عرض المستخدمين وتفعيل أو تعطيل الحسابات",
          icon: Icons.people_alt_outlined,
          onTap: () => onNavigateToTab(1),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          title: "إدارة المشافي",
          subtitle: "إضافة وتعديل وحذف بيانات المشافي",
          icon: Icons.local_hospital_outlined,
          onTap: () => onNavigateToTab(2),
        ),
        const SizedBox(height: 12),
        _AdminActionCard(
          title: "إدارة المخابر",
          subtitle: "إضافة وتعديل وحذف بيانات المخابر",
          icon: Icons.biotech_outlined,
          onTap: () => onNavigateToTab(3),
        ),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color cardColor = theme.cardTheme.color ?? cs.surfaceContainerLowest;

    final Color titleColor = cs.onSurface.withValues(alpha: 0.92);
    final Color subtitleColor = cs.onSurface.withValues(alpha: 0.72);
    final Color chevronColor = cs.onSurface.withValues(alpha: 0.55);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: chevronColor),
            ],
          ),
        ),
      ),
    );
  }
}
