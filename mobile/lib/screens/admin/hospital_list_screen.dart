import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/services/governorate_service.dart';
import '/services/hospital_service.dart';
import '/utils/ui_helpers.dart';
import 'hospital_form_screen.dart';

class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  final hospitalService = HospitalService();
  final governorateService = GovernorateService();

  late Future<List<Hospital>> futureHospitals;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    loadHospitals();
    loadGovernorates();

    searchController.addListener(() {
      final next = searchController.text.trim();
      if (next == searchQuery) return;
      setState(() => searchQuery = next);
    });
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
    if (!mounted) return;
    setState(() => loadingGovernorates = true);

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

      // Fetch error => Inline أفضل، لكن هذا جزء مساعد للشاشة.
      // بما أن الشاشة نفسها لديها FutureBuilder لعرض الحالة، Snackbar هنا مقبول كتنبيه سريع.
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل تحميل المحافظات.',
      );
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(loadHospitals);
    await loadGovernorates();
  }

  Future<void> deleteHospital(Hospital hospital) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف المشفى: ${hospital.name} ؟',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!confirmed) return;

    try {
      await hospitalService.deleteHospital(hospital.id!);
    } catch (e) {
      if (!mounted) return;

      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر حذف المشفى. حاول مرة أخرى.',
      );
      return;
    }

    if (!mounted) return;

    showAppSnackBar(
      context,
      'تم حذف المشفى بنجاح.',
      type: AppSnackBarType.success,
    );

    await refresh();
  }

  Future<void> openForm({Hospital? hospital}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HospitalFormScreen(hospital: hospital)),
    );

    if (!mounted) return;

    if (saved == true) {
      await refresh();
    }
  }

  bool matchesSearch(Hospital hospital) {
    final q = searchQuery.toLowerCase();
    if (q.isEmpty) return true;

    final name = hospital.name.toLowerCase();
    final specialty = (hospital.specialty ?? '').toLowerCase();
    final contact = (hospital.contactInfo ?? '').toLowerCase();
    final address = (hospital.address ?? '').toLowerCase();
    final govName =
        (governorateNamesById[hospital.governorate] ?? '').toLowerCase();

    return name.contains(q) ||
        specialty.contains(q) ||
        contact.contains(q) ||
        address.contains(q) ||
        govName.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Material(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم / المحافظة / التخصص / العنوان...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          searchQuery.isEmpty
                              ? null
                              : IconButton(
                                tooltip: 'مسح البحث',
                                onPressed: () => searchController.clear(),
                                icon: const Icon(Icons.close),
                              ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
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
                    return AppFetchStateView(
                      error: snapshot.error!,
                      onRetry: refresh,
                    );
                  }

                  final hospitals = snapshot.data ?? [];
                  final visible = hospitals.where(matchesSearch).toList();

                  if (hospitals.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'لا يوجد مشافي مسجّلة.\nاضغط زر الإضافة لإدخال مشفى جديد.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (visible.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'لا توجد نتائج مطابقة.\nجرّب تعديل كلمة البحث.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 90),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final h = visible[index];
                        final govName = governorateNamesById[h.governorate];

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            title: Text(
                              h.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _InfoRow(
                                    icon: Icons.location_on_outlined,
                                    text: 'المحافظة: ${govName ?? '—'}',
                                  ),
                                  if (h.specialty != null &&
                                      h.specialty!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.medical_services_outlined,
                                      text: 'التخصص: ${h.specialty}',
                                    ),
                                  if (h.contactInfo != null &&
                                      h.contactInfo!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.call_outlined,
                                      text: 'الاتصال: ${h.contactInfo}',
                                    ),
                                  if (h.address != null &&
                                      h.address!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.home_outlined,
                                      text: 'العنوان: ${h.address}',
                                    ),
                                ],
                              ),
                            ),
                            onTap: () => openForm(hospital: h),
                            trailing: IconButton(
                              tooltip: 'حذف',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => deleteHospital(h),
                            ),
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
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'hospitalFab',
            onPressed: () => openForm(),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.78),
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
