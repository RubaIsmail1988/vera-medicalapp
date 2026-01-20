import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../services/appointments_service.dart';
import '../../../models/doctor_search_result.dart';
import '../../../utils/ui_helpers.dart';

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

  int? selectedGovernorateId; // null => الكل

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<_GovernorateOption> get governorateOptions {
    final map = <int, String>{};

    for (final d in results) {
      final id = d.governorateId;
      final name = d.governorateName;

      if (id != null && name != null && name.trim().isNotEmpty) {
        map[id] = name.trim();
      }
    }

    final options =
        map.entries
            .map((e) => _GovernorateOption(id: e.key, name: e.value))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return options;
  }

  List<DoctorSearchResult> get filteredResults {
    final gid = selectedGovernorateId;
    if (gid == null) return results;
    return results.where((d) => d.governorateId == gid).toList();
  }

  Future<void> runSearch() async {
    final q = searchController.text.trim();
    if (q.isEmpty) {
      setState(() {
        query = '';
        results = const [];
        errorMessage = null;
        selectedGovernorateId = null;
      });
      return;
    }

    setState(() {
      loading = true;
      query = q;
      errorMessage = null;
      // ملاحظة: لا نصفر الفلتر هنا، لأن المستخدم قد يريد تثبيته أثناء تغيير كلمة البحث
      // لكن إذا تحبي تصفيره تلقائياً عند كل بحث، اكتبي:
      // selectedGovernorateId = null;
    });

    try {
      final data = await appointmentsService.searchDoctors(query: q);
      if (!mounted) return;

      setState(() {
        results = data;
        debugPrint('Doctors returned: ${data.length}');
        if (data.isNotEmpty) {
          final d0 = data.first;
          debugPrint(
            'Sample: id=${d0.id}, name=${d0.username}, govId=${d0.governorateId}, govName=${d0.governorateName}, exp=${d0.experienceYears}',
          );
        }

        loading = false;

        // إذا كانت المحافظة المحددة لم تعد موجودة ضمن النتائج الجديدة → رجّعيها "الكل"
        final existingIds = governorateOptions.map((e) => e.id).toSet();
        if (selectedGovernorateId != null &&
            !existingIds.contains(selectedGovernorateId)) {
          selectedGovernorateId = null;
        }
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
        'doctorGovernorateName': doctor.governorateName,
        'doctorExperienceYears': doctor.experienceYears,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;
    final govOptions = governorateOptions;
    final dataToShow = filteredResults;

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
                hintText: 'مثال: عظم، أسنان، أحمد...',
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

            // فلتر المحافظات (يظهر فقط إذا لدينا نتائج)
            if (results.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                value: selectedGovernorateId,
                decoration: const InputDecoration(labelText: 'المحافظة'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('كل المحافظات'),
                  ),
                  ...govOptions.map(
                    (g) => DropdownMenuItem<int?>(
                      value: g.id,
                      child: Text(g.name),
                    ),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    selectedGovernorateId = v;
                  });
                },
              ),
              const SizedBox(height: 12),
            ],

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

                  if (dataToShow.isEmpty) {
                    // قد تكون النتائج الأصلية موجودة لكن الفلتر ضيّقها
                    if (results.isNotEmpty && selectedGovernorateId != null) {
                      return const Center(
                        child: Text('لا توجد نتائج ضمن هذه المحافظة.'),
                      );
                    }
                    return const Center(child: Text('لا توجد نتائج.'));
                  }

                  return ListView.separated(
                    itemCount: dataToShow.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final d = dataToShow[i];

                      final specialty = d.specialty;
                      final exp = d.experienceYears;
                      final gov = d.governorateName ?? '';

                      final line1 =
                          exp != null
                              ? '$specialty • خبرة $exp سنوات'
                              : specialty;

                      final line2 =
                          gov.trim().isNotEmpty
                              ? 'المحافظة: ${gov.trim()}'
                              : '';

                      return Card(
                        elevation: 0,
                        child: ListTile(
                          title: Text(d.username),
                          subtitle: Text(
                            line2.isEmpty ? line1 : '$line1\n$line2',
                          ),
                          isThreeLine: line2.isNotEmpty,
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

class _GovernorateOption {
  final int id;
  final String name;

  const _GovernorateOption({required this.id, required this.name});
}
