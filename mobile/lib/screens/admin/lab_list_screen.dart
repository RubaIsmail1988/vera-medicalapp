import 'package:flutter/material.dart';

import '/models/lab.dart';
//import '/models/governorate.dart';
import '/services/lab_service.dart';
import '/services/governorate_service.dart';
import '../admin/lab_form_screen.dart';

class LabListScreen extends StatefulWidget {
  const LabListScreen({super.key});

  @override
  State<LabListScreen> createState() => _LabListScreenState();
}

class _LabListScreenState extends State<LabListScreen> {
  final labService = LabService();
  final governorateService = GovernorateService();

  late Future<List<Lab>> futureLabs;

  final searchController = TextEditingController();
  String searchQuery = '';

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    loadLabs();
    loadGovernorates();

    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.trim();
      });
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
    setState(() {
      loadingGovernorates = true;
    });

    try {
      final items = await governorateService.fetchGovernorates();
      if (!mounted) return;

      setState(() {
        governorateNamesById = {for (final g in items) g.id: g.name};
        loadingGovernorates = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingGovernorates = false;
      });
    }
  }

  Future<void> refresh() async {
    setState(() {
      loadLabs();
    });
    await loadGovernorates();
  }

  Future<void> deleteLab(Lab lab) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("تأكيد الحذف"),
            content: Text("هل أنت متأكد من حذف المخبر: ${lab.name}؟"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("حذف"),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final success = await labService.deleteLab(lab.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? "تم حذف المخبر" : "فشل حذف المخبر")),
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

    if (saved == true && mounted) {
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

    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المخابر")),
      body: Column(
        children: [
          // Search UI
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "بحث بالاسم / المحافظة / الاختصاص / العنوان...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    searchQuery.isEmpty
                        ? null
                        : IconButton(
                          tooltip: "مسح البحث",
                          onPressed: () => searchController.clear(),
                          icon: const Icon(Icons.close),
                        ),
                filled: true,
                fillColor: cs.surface.withValues(alpha: 0.6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
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
                  return const Center(child: Text("خطأ في تحميل المخابر"));
                }

                final labs = snapshot.data ?? [];
                final visible = labs.where(matchesSearch).toList();

                if (labs.isEmpty) {
                  return const Center(child: Text("لا يوجد مخابر مسجلة"));
                }

                if (visible.isEmpty) {
                  return const Center(
                    child: Text("لا توجد نتائج مطابقة للبحث."),
                  );
                }

                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final lab = visible[index];
                      final govName = governorateNamesById[lab.governorate];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(lab.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("المحافظة: ${govName ?? '—'}"),
                              if (lab.specialty != null &&
                                  lab.specialty!.isNotEmpty)
                                Text("الاختصاص: ${lab.specialty}"),
                              if (lab.contactInfo != null &&
                                  lab.contactInfo!.isNotEmpty)
                                Text("الاتصال: ${lab.contactInfo}"),
                              if (lab.address != null &&
                                  lab.address!.isNotEmpty)
                                Text("العنوان: ${lab.address}"),
                            ],
                          ),
                          onTap: () => openForm(lab: lab),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'labFab',
        onPressed: () => openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
