// mobile/lib/screens/user/appointments/doctor_search_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../models/doctor_search_result.dart';
import '../../../services/appointments_service.dart';
import '../../../services/auth_service.dart';
import '../../../utils/ui_helpers.dart';

class DoctorSearchScreen extends StatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen> {
  final TextEditingController searchController = TextEditingController();
  final AppointmentsService appointmentsService = AppointmentsService();

  // for /api/accounts/me/
  final AuthService authService = AuthService();

  bool loading = false;
  String query = '';
  List<DoctorSearchResult> results = const [];

  int? selectedGovernorateId; // null => الكل
  int? myGovernorateId; // from /api/accounts/me/
  bool profileLoaded = false;
  bool userTouchedGovernorateFilter = false;

  // Fetch error (موحّد)
  ({String title, String message, IconData icon})? inlineError;

  @override
  void initState() {
    super.initState();
    _loadMyGovernorateDefault();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ---------------- Accounts (/me) helpers ----------------

  Future<void> _loadMyGovernorateDefault() async {
    if (profileLoaded) return;

    try {
      final response = await authService.authorizedRequest("/me/", "GET");
      if (!mounted) return;

      if (response.statusCode != 200) {
        setState(() {
          profileLoaded = true;
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      int? govId;

      if (decoded is Map) {
        final rawGov = decoded["governorate"];
        if (rawGov is int) govId = rawGov;
        if (rawGov is num) govId = rawGov.toInt();
        if (rawGov is String) govId = int.tryParse(rawGov);
      }

      setState(() {
        myGovernorateId = govId;
        profileLoaded = true;

        // Default selection = patient's governorate,
        // but do not override if user already changed it.
        if (!userTouchedGovernorateFilter && selectedGovernorateId == null) {
          selectedGovernorateId = govId;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profileLoaded = true;
      });
    }
  }

  // ---------------- UI data helpers ----------------

  List<_GovernorateOption> get governorateOptions {
    final map = <int, String>{};

    for (final d in results) {
      final id = d.governorateId;
      final name = d.governorateName;

      if (id != null && name != null && name.trim().isNotEmpty) {
        map[id] = name.trim();
      }
    }

    return map.entries
        .map((e) => _GovernorateOption(id: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<DoctorSearchResult> get filteredResults {
    final gid = selectedGovernorateId;
    if (gid == null) return results;
    return results.where((d) => d.governorateId == gid).toList();
  }

  List<DoctorSearchResult> _sortedForMyGovernorateFirst(
    List<DoctorSearchResult> input,
  ) {
    final govId = myGovernorateId;
    if (govId == null) return input;

    // If user explicitly selected a governorate, respect that (no extra sorting needed)
    if (selectedGovernorateId != null) return input;

    final list = List<DoctorSearchResult>.from(input);

    list.sort((a, b) {
      final aMatch = a.governorateId == govId ? 0 : 1;
      final bMatch = b.governorateId == govId ? 0 : 1;

      if (aMatch != bMatch) return aMatch.compareTo(bMatch);

      // secondary ordering: username
      return a.username.compareTo(b.username);
    });

    return list;
  }

  // ---------------- API call ----------------

  Future<void> runSearch() async {
    final q = searchController.text.trim();

    if (q.isEmpty) {
      setState(() {
        query = '';
        results = const [];
        inlineError = null;

        // لا نلمس فلتر المحافظة هنا:
        // - إذا المستخدم لم يلمس الفلتر: يبقى الافتراضي (محافظة الحساب)
        // - إذا المستخدم اختار: نحترم اختياره
      });
      return;
    }

    setState(() {
      loading = true;
      query = q;
      inlineError = null;
    });

    try {
      final data = await appointmentsService.searchDoctors(query: q);
      if (!mounted) return;

      setState(() {
        results = data;
        loading = false;

        // إذا المستخدم مختار محافظة، وتبين أنها غير موجودة ضمن النتائج الجديدة → رجّعيها "الكل"
        if (selectedGovernorateId != null) {
          final ids = data.map((d) => d.governorateId).whereType<int>().toSet();
          if (!ids.contains(selectedGovernorateId)) {
            selectedGovernorateId = null;
            userTouchedGovernorateFilter = false;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      final mapped = mapFetchExceptionToInlineState(e);

      setState(() {
        loading = false;
        results = const [];
        inlineError = (
          title: mapped.title,
          message: mapped.message,
          icon: mapped.icon,
        );
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

    final baseList = filteredResults;
    final dataToShow = _sortedForMyGovernorateFirst(baseList);

    final showGovFilter = results.isNotEmpty;

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

            // فلتر المحافظات
            if (showGovFilter) ...[
              DropdownButtonFormField<int?>(
                value: selectedGovernorateId,
                decoration: InputDecoration(
                  labelText: 'المحافظة',
                  helperText:
                      (!profileLoaded)
                          ? 'جارٍ تحميل محافظة حسابك...'
                          : (myGovernorateId != null
                              ? 'تم ضبط الافتراضي على محافظة حسابك (يمكنك تغييره).'
                              : 'يمكنك اختيار المحافظة لتصفية النتائج.'),
                ),
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
                    userTouchedGovernorateFilter = true;
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

                  if (inlineError != null && results.isEmpty) {
                    final err = inlineError!;
                    return AppInlineErrorState(
                      title: err.title,
                      message: err.message,
                      icon: err.icon,
                      onRetry: runSearch,
                    );
                  }

                  if (dataToShow.isEmpty) {
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
