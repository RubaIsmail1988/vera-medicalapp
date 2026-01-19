import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/models/lab.dart';
import '/services/lab_service.dart';
import '/services/governorate_service.dart';
import '/utils/ui_helpers.dart';

class LabPublicListScreen extends StatefulWidget {
  const LabPublicListScreen({super.key});

  @override
  State<LabPublicListScreen> createState() => _LabPublicListScreenState();
}

class _LabPublicListScreenState extends State<LabPublicListScreen> {
  final LabService labService = LabService();
  final GovernorateService governorateService = GovernorateService();

  late Future<List<Lab>> futureLabs;

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    loadLabs();
    loadGovernorates();
  }

  void loadLabs() {
    futureLabs = labService.fetchLabs();
  }

  Future<void> loadGovernorates() async {
    if (mounted) {
      setState(() => loadingGovernorates = true);
    }

    try {
      final items = await governorateService.fetchGovernorates();
      if (!mounted) return;

      setState(() {
        governorateNamesById = {for (final g in items) g.id: g.name};
        loadingGovernorates = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loadingGovernorates = false);

      showAppSnackBar(
        context,
        'فشل تحميل المحافظات: $e',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(loadLabs);
    await loadGovernorates();
  }

  void openDetails(Lab lab) {
    context.push(
      '/app/labs/detail',
      extra: {
        'name': lab.name,
        'governorate': lab.governorate,
        'governorateName': governorateNamesById[lab.governorate],
        'address': lab.address,
        'latitude': lab.latitude,
        'longitude': lab.longitude,
        'specialty': lab.specialty,
        'contactInfo': lab.contactInfo,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          if (loadingGovernorates)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: LinearProgressIndicator(),
            ),
          Expanded(
            child: FutureBuilder<List<Lab>>(
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
                  return const Center(
                    child: Text('لا توجد مخابر متاحة حاليًا.'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: labs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lab = labs[index];
                      final govName = governorateNamesById[lab.governorate];

                      return Card(
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            lab.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoRow(
                                  icon: Icons.location_city,
                                  text: govName ?? '—',
                                ),
                                if (lab.specialty != null &&
                                    lab.specialty!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.science_outlined,
                                    text: lab.specialty!,
                                  ),
                                if (lab.contactInfo != null &&
                                    lab.contactInfo!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.phone_outlined,
                                    text: lab.contactInfo!,
                                    textColor: cs.primary,
                                  ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                          onTap: () => openDetails(lab),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? textColor;

  const _InfoRow({required this.icon, required this.text, this.textColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: textColor ?? cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
