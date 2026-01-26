import 'package:flutter/material.dart';

import '/models/lab.dart';
import '/services/governorate_service.dart';
import '/services/lab_service.dart';
import '/utils/ui_helpers.dart';
import 'lab_form_screen.dart';

class LabListScreen extends StatefulWidget {
  const LabListScreen({super.key});

  @override
  State<LabListScreen> createState() => _LabListScreenState();
}

class _LabListScreenState extends State<LabListScreen> {
  final labService = LabService();
  final governorateService = GovernorateService();

  late Future<List<Lab>> futureLabs;

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    loadLabs();
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

  void loadLabs() {
    futureLabs = labService.fetchLabs();
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

      // Fetch => نعرض رسالة واضحة موحّدة بدون تفاصيل
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'فشل تحميل المحافظات.',
      );
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(loadLabs);
    await loadGovernorates();
  }

  Future<void> deleteLab(Lab lab) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف المخبر: ${lab.name} ؟',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      danger: true,
    );

    if (!confirmed) return;

    try {
      final success = await labService.deleteLab(lab.id!);
      if (!mounted) return;

      showAppSnackBar(
        context,
        success ? 'تم حذف المخبر بنجاح.' : 'فشل حذف المخبر.',
        type: success ? AppSnackBarType.success : AppSnackBarType.error,
      );

      if (success) {
        await refresh();
      }
    } catch (e) {
      if (!mounted) return;

      // Action => SnackBar موحّد
      showActionErrorSnackBar(
        context,
        exception: e,
        fallback: 'تعذّر حذف المخبر.',
      );
    }
  }

  Future<void> openForm({Lab? lab}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LabFormScreen(lab: lab)),
    );

    if (!mounted) return;

    if (saved == true) {
      await refresh();
    }
  }

  bool matchesSearch(Lab lab) {
    final q = searchQuery.toLowerCase();
    if (q.isEmpty) return true;

    final name = lab.name.toLowerCase();
    final specialty = (lab.specialty ?? '').toLowerCase();
    final contact = (lab.contactInfo ?? '').toLowerCase();
    final address = (lab.address ?? '').toLowerCase();
    final govName = (governorateNamesById[lab.governorate] ?? '').toLowerCase();

    return name.contains(q) ||
        specialty.contains(q) ||
        contact.contains(q) ||
        address.contains(q) ||
        govName.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // مهم: بدون Scaffold وبدون AppBar (لأنها داخل AdminShell)
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
                      hintText: 'بحث بالاسم / المحافظة / الاختصاص / العنوان...',
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
              child: FutureBuilder<List<Lab>>(
                future: futureLabs,
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

                  final labs = snapshot.data ?? [];
                  final visible = labs.where(matchesSearch).toList();

                  if (labs.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'لا يوجد مخابر مسجّلة.\nاضغط زر الإضافة لإدخال مخبر جديد.',
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
                        final lab = visible[index];
                        final govName = governorateNamesById[lab.governorate];

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            title: Text(
                              lab.name,
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
                                  if (lab.specialty != null &&
                                      lab.specialty!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.medical_services_outlined,
                                      text: 'الاختصاص: ${lab.specialty}',
                                    ),
                                  if (lab.contactInfo != null &&
                                      lab.contactInfo!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.call_outlined,
                                      text: 'الاتصال: ${lab.contactInfo}',
                                    ),
                                  if (lab.address != null &&
                                      lab.address!.trim().isNotEmpty)
                                    _InfoRow(
                                      icon: Icons.home_outlined,
                                      text: 'العنوان: ${lab.address}',
                                    ),
                                ],
                              ),
                            ),
                            onTap: () => openForm(lab: lab),
                            trailing: IconButton(
                              tooltip: 'حذف',
                              icon: Icon(Icons.delete_outline, color: cs.error),
                              onPressed: () => deleteLab(lab),
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
            heroTag: 'labFab',
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
