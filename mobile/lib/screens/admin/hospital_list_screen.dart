import 'package:flutter/material.dart';

import '/models/hospital.dart';
import '/services/hospital_service.dart';
import '../admin/hospital_form_screen.dart';

class HospitalListScreen extends StatefulWidget {
  const HospitalListScreen({super.key});

  @override
  State<HospitalListScreen> createState() => _HospitalListScreenState();
}

class _HospitalListScreenState extends State<HospitalListScreen> {
  final HospitalService _hospitalService = HospitalService();

  late Future<List<Hospital>> _futureHospitals;

  @override
  void initState() {
    super.initState();
    _loadHospitals();
  }

  void _loadHospitals() {
    _futureHospitals = _hospitalService.fetchHospitals();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadHospitals();
    });
  }

  Future<void> _deleteHospital(Hospital hospital) async {
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

    final success = await _hospitalService.deleteHospital(hospital.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? "تم حذف المشفى بنجاح" : "فشل حذف المشفى"),
      ),
    );

    if (success) {
      _refresh();
    }
  }

  void _openForm({Hospital? hospital}) async {
    final bool? saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HospitalFormScreen(hospital: hospital)),
    );

    if (saved == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المشافي")),
      body: FutureBuilder<List<Hospital>>(
        future: _futureHospitals,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("حدث خطأ أثناء تحميل المشافي."));
          }

          final hospitals = snapshot.data ?? [];

          if (hospitals.isEmpty) {
            return const Center(child: Text("لا يوجد مشافي مسجلة."));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: hospitals.length,
              itemBuilder: (context, index) {
                final h = hospitals[index];
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
                        Text("المحافظة (ID): ${h.governorate}"),
                        if (h.specialty != null &&
                            h.specialty!.trim().isNotEmpty)
                          Text("التخصص: ${h.specialty}"),
                        if (h.contactInfo != null &&
                            h.contactInfo!.trim().isNotEmpty)
                          Text("الاتصال: ${h.contactInfo}"),
                      ],
                    ),
                    onTap: () => _openForm(hospital: h),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteHospital(h),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
