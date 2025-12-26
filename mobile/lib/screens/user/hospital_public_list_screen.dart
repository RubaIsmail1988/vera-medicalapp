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

  @override
  void initState() {
    super.initState();
    loadHospitals();
    loadGovernorates();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    //  بدون Scaffold وبدون AppBar (لأنها داخل UserShell)
    return Column(
      children: [
        if (loadingGovernorates)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(),
          ),
        Expanded(
          child: FutureBuilder<List<Hospital>>(
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

              return RefreshIndicator(
                onRefresh: refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: hospitals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final hospital = hospitals[index];
                    final govName = governorateNamesById[hospital.governorate];

                    return Card(
                      child: ListTile(
                        title: Text(hospital.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('المحافظة: ${govName ?? '—'}'),
                            if (hospital.specialty != null &&
                                hospital.specialty!.trim().isNotEmpty)
                              Text('التخصص: ${hospital.specialty}'),
                            if (hospital.contactInfo != null &&
                                hospital.contactInfo!.trim().isNotEmpty)
                              Text('الاتصال: ${hospital.contactInfo}'),
                          ],
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
    );
  }
}
