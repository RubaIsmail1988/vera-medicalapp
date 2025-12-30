import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../services/appointments_service.dart';
import '../../../models/doctor_search_result.dart';
import '../../../utils/ui_helpers.dart';
import 'package:go_router/go_router.dart';

class DoctorSearchScreen extends StatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final AppointmentsService appointmentsService = AppointmentsService();

  bool loading = false;
  String query = '';
  List<DoctorSearchResult> results = const [];
  String? errorMessage;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> runSearch() async {
    final q = searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        query = '';
        results = const [];
        errorMessage = null;
      });
      return;
    }

    setState(() {
      loading = true;
      query = q;
      errorMessage = null;
    });

    try {
      final data = await appointmentsService.searchDoctors(query: q);

      if (!mounted) return;

      setState(() {
        results = data;
        loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      Object? body;
      try {
        body = jsonDecode(e.body);
      } catch (_) {
        body = e.body;
      }

      showApiErrorSnackBar(context, statusCode: e.statusCode, data: body);

      setState(() {
        loading = false;
        errorMessage = mapHttpErrorToArabicMessage(
          statusCode: e.statusCode,
          data: body,
        );
      });
    } catch (_) {
      if (!mounted) return;

      const msg = 'حدث خطأ غير متوقع. حاول مرة أخرى لاحقًا.';
      showAppErrorSnackBar(context, msg);

      setState(() {
        loading = false;
        errorMessage = msg;
      });
    }
  }

  void openBooking(DoctorSearchResult doctor) {
    context.go(
      '/app/appointments/book/${doctor.id}',
      extra: {
        'doctorName': doctor.username,
        'doctorSpecialty': doctor.specialty,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('حجز موعد')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => runSearch(),
              decoration: InputDecoration(
                labelText: 'ابحث باسم الطبيب أو بالاختصاص',
                hintText: 'مثال: عظم، أسنان، doctor33...',
                suffixIcon: IconButton(
                  tooltip: 'بحث',
                  onPressed: loading ? null : runSearch,
                  icon:
                      loading
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Builder(
                builder: (_) {
                  if (!hasQuery && results.isEmpty) {
                    return const Center(
                      child: Text('ابدأ بالبحث لاختيار الطبيب.'),
                    );
                  }

                  if (loading && results.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (errorMessage != null && results.isEmpty) {
                    return Center(child: Text(errorMessage!));
                  }

                  if (results.isEmpty) {
                    return const Center(child: Text('لا توجد نتائج.'));
                  }

                  return ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final d = results[i];
                      return Card(
                        elevation: 0,
                        child: ListTile(
                          title: Text(d.username),
                          subtitle: Text(d.specialty),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => openBooking(d),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
