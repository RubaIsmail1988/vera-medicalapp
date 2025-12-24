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
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingGovernorates = false);

      showAppSnackBar(
        context,
        'فشل تحميل المحافظات.',
        type: AppSnackBarType.error,
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
                    return const _CenteredStatus(
                      icon: Icons.hourglass_top_rounded,
                      title: 'جاري تحميل المخابر...',
                      showProgress: true,
                    );
                  }

                  if (snapshot.hasError) {
                    return _CenteredStatus(
                      icon: Icons.error_outline,
                      title: 'تعذّر تحميل المخابر.',
                      subtitle: 'تحقق من الاتصال ثم أعد المحاولة.',
                      actionText: 'إعادة المحاولة',
                      onAction: refresh,
                    );
                  }

                  final labs = snapshot.data ?? [];
                  final visible = labs.where(matchesSearch).toList();

                  if (labs.isEmpty) {
                    return const _CenteredStatus(
                      icon: Icons.biotech_outlined,
                      title: 'لا يوجد مخابر مسجّلة.',
                      subtitle: 'اضغط زر الإضافة لإدخال مخبر جديد.',
                    );
                  }

                  if (visible.isEmpty) {
                    return const _CenteredStatus(
                      icon: Icons.search_off,
                      title: 'لا توجد نتائج مطابقة.',
                      subtitle: 'جرّب تعديل كلمة البحث.',
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

class _CenteredStatus extends StatelessWidget {
  const _CenteredStatus({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final Future<void> Function()? onAction;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: cs.onSurface.withValues(alpha: 0.70)),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
              if (showProgress) ...[
                const SizedBox(height: 14),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () async {
                    await onAction!.call();
                  },
                  child: Text(actionText!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
