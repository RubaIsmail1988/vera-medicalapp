import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/services/hospital_service.dart';
//import '/models/governorate.dart';
import '/services/governorate_service.dart';
import '../admin/hospital_form_screen.dart';

class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  final hospitalService = HospitalService();
  final governorateService = GovernorateService();

  late Future<List<Hospital>> futureHospitals;

  final searchController = TextEditingController();
  String searchQuery = '';

  Map<int, String> governorateNamesById = {};
  bool loadingGovernorates = true;

  @override
  void initState() {
    super.initState();
    loadHospitals();
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

  void loadHospitals() {
    futureHospitals = hospitalService.fetchHospitals();
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
      loadHospitals();
    });
    await loadGovernorates();
  }

  Future<void> deleteHospital(Hospital hospital) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("تأكيد الحذف"),
            content: Text("هل أنت متأكد من حذف المشفى: ${hospital.name}؟"),
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

    final success = await hospitalService.deleteHospital(hospital.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "تم حذف المشفى بنجاح" : "فشل حذف المشفى"),
      ),
    );

    if (success) {
      await refresh();
    }
  }

  Future<void> openForm({Hospital? hospital}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => HospitalFormScreen(hospital: hospital)),
    );

    if (saved == true && mounted) {
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

    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المشافي")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "بحث بالاسم / المحافظة / التخصص / العنوان...",
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
            child: FutureBuilder<List<Hospital>>(
              future: futureHospitals,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text("حدث خطأ أثناء تحميل المشافي."),
                  );
                }

                final hospitals = snapshot.data ?? [];
                final visible = hospitals.where(matchesSearch).toList();

                if (hospitals.isEmpty) {
                  return const Center(child: Text("لا يوجد مشافي مسجلة."));
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
                      final h = visible[index];
                      final govName = governorateNamesById[h.governorate];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(h.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("المحافظة: ${govName ?? '—'}"),
                              if (h.specialty != null &&
                                  h.specialty!.trim().isNotEmpty)
                                Text("التخصص: ${h.specialty}"),
                              if (h.contactInfo != null &&
                                  h.contactInfo!.trim().isNotEmpty)
                                Text("الاتصال: ${h.contactInfo}"),
                              if (h.address != null &&
                                  h.address!.trim().isNotEmpty)
                                Text("العنوان: ${h.address}"),
                            ],
                          ),
                          onTap: () => openForm(hospital: h),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'hospitalFab',
        onPressed: () => openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
