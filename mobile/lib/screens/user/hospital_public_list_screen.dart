import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/models/hospital.dart';
import '/services/hospital_service.dart';
import '/services/governorate_service.dart';
import '/utils/ui_helpers.dart';

class HospitalPublicListScreen extends StatefulWidget {
  const HospitalPublicListScreen({super.key});

  @override
  State<HospitalPublicListScreen> createState() =>
      _HospitalPublicListScreenState();
}

class _HospitalPublicListScreenState extends State<HospitalPublicListScreen> {
  final HospitalService hospitalService = HospitalService();
  final GovernorateService governorateService = GovernorateService();

  late Future<List<Hospital>> futureHospitals;

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadHospitals();
    loadGovernorates();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void loadHospitals() {
    futureHospitals = hospitalService.fetchHospitals();
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
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingGovernorates = false);
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(loadHospitals);
    await loadGovernorates();
  }

  void openDetails(Hospital hospital) {
    final govName = governorateNamesById[hospital.governorate];

    context.push(
      '/app/hospitals/detail',
      extra: {
        'name': hospital.name,
        'governorate': hospital.governorate,
        'governorateName': govName,
        'address': hospital.address,
        'latitude': hospital.latitude,
        'longitude': hospital.longitude,
        'specialty': hospital.specialty,
        'contactInfo': hospital.contactInfo,
      },
    );
  }

  List<Hospital> _applySearchAndSort(List<Hospital> hospitals) {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return hospitals;

    bool matches(Hospital h) {
      final nameMatch = h.name.toLowerCase().contains(q);
      final govName = governorateNamesById[h.governorate]?.toLowerCase() ?? '';
      final govMatch = govName.contains(q);
      return nameMatch || govMatch;
    }

    final filtered = hospitals.where(matches).toList();

    // ترتيب: المطابق للمحافظة أولًا
    filtered.sort((a, b) {
      final govA = governorateNamesById[a.governorate]?.toLowerCase() ?? '';
      final govB = governorateNamesById[b.governorate]?.toLowerCase() ?? '';

      final aGovMatch = govA.contains(q);
      final bGovMatch = govB.contains(q);

      if (aGovMatch && !bGovMatch) return -1;
      if (!aGovMatch && bGovMatch) return 1;
      return a.name.compareTo(b.name);
    });

    return filtered;
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

          // ---- Search Field ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: searchController,
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المشفى أو المحافظة',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Hospital>>(
              future: futureHospitals,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  final mapped = mapFetchExceptionToInlineState(
                    snapshot.error!,
                  );

                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(
                      children: [
                        const SizedBox(height: 80),
                        AppInlineErrorState(
                          title: mapped.title,
                          message: mapped.message,
                          icon: mapped.icon,
                          onRetry: refresh,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                }

                final hospitals = snapshot.data ?? [];
                final visible = _applySearchAndSort(hospitals);

                if (visible.isEmpty) {
                  return const Center(child: Text('لا توجد نتائج مطابقة.'));
                }

                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final hospital = visible[index];
                      final govName =
                          governorateNamesById[hospital.governorate];

                      return Card(
                        elevation: 1,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          title: Text(
                            hospital.name,
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
                                if (hospital.specialty != null &&
                                    hospital.specialty!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.medical_services_outlined,
                                    text: hospital.specialty!,
                                  ),
                                if (hospital.contactInfo != null &&
                                    hospital.contactInfo!.trim().isNotEmpty)
                                  _InfoRow(
                                    icon: Icons.phone_outlined,
                                    text: hospital.contactInfo!,
                                    textColor: cs.primary,
                                  ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                          onTap: () => openDetails(hospital),
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
