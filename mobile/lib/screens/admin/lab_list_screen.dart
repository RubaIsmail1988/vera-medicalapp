import 'package:flutter/material.dart';

import '/models/lab.dart';
import '/services/lab_service.dart';
import '../admin/lab_form_screen.dart';

class LabListScreen extends StatefulWidget {
  const LabListScreen({super.key});

  @override
  State<LabListScreen> createState() => _LabListScreenState();
}

class _LabListScreenState extends State<LabListScreen> {
  final LabService _labService = LabService();
  late Future<List<Lab>> _futureLabs;

  @override
  void initState() {
    super.initState();
    _loadLabs();
  }

  void _loadLabs() {
    _futureLabs = _labService.fetchLabs();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadLabs();
    });
  }

  Future<void> _deleteLab(Lab lab) async {
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

    final success = await _labService.deleteLab(lab.id!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? "تم حذف المخبر" : "فشل حذف المخبر")),
    );

    if (success) {
      _refresh();
    }
  }

  void _openForm({Lab? lab}) async {
    final bool? saved = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabFormScreen(lab: lab)),
    );

    if (saved == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المخابر")),
      body: FutureBuilder<List<Lab>>(
        future: _futureLabs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text("خطأ في تحميل المخابر"));
          }

          final labs = snapshot.data ?? [];

          if (labs.isEmpty) {
            return const Center(child: Text("لا يوجد مخابر مسجلة"));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: labs.length,
              itemBuilder: (context, index) {
                final lab = labs[index];
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
                        Text("المحافظة (ID): ${lab.governorate}"),
                        if (lab.specialty != null && lab.specialty!.isNotEmpty)
                          Text("الاختصاص: ${lab.specialty}"),
                        if (lab.contactInfo != null &&
                            lab.contactInfo!.isNotEmpty)
                          Text("الاتصال: ${lab.contactInfo}"),
                      ],
                    ),
                    onTap: () => _openForm(lab: lab),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteLab(lab),
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
