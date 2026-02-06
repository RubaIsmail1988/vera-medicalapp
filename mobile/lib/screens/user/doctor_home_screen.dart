// lib/screens/user/doctor_home_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/analytics/doctor_home_analytics.dart';
import '/models/appointment.dart';
import '/models/doctor_appointment_type.dart';
import '/models/doctor_availability.dart';
import '/services/appointments_service.dart';
import '/services/auth_service.dart';
import '/utils/api_exception.dart';
import '/utils/ui_helpers.dart';

// -----------------------------------------------------------------------------
// Screen
// -----------------------------------------------------------------------------
class DoctorHomeScreen extends StatefulWidget {
  final int userId;
  final String token;
  final void Function(DoctorAnalytics analytics)? onAnalyticsLoaded;

  const DoctorHomeScreen({
    super.key,
    required this.userId,
    required this.token,
    this.onAnalyticsLoaded,
  });

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  final AppointmentsService appointmentsService = AppointmentsService();
  final AuthService authService = AuthService();
  DoctorAnalytics? _lastSentAnalytics;

  String? userName;
  late Future<DoctorHomeData> homeFuture;

  static const int daysCount = 7;

  @override
  void initState() {
    super.initState();
    homeFuture = _loadHomeData();
    // ignore: unawaited_futures
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('currentUserName');

    if (!mounted) return;

    setState(() {
      userName = savedName;
    });
  }

  Future<List<DoctorAvailability>> _fetchMyAvailabilities() async {
    final response = await authService.authorizedRequest(
      "/doctor-availabilities/",
      "GET",
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map((e) => DoctorAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<List<DoctorAppointmentType>> _fetchDoctorAppointmentTypes() async {
    final response = await authService.authorizedRequest(
      "/doctor-appointment-types/",
      "GET",
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .map(
              (e) => DoctorAppointmentType.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      throw const ApiException(500, 'Unexpected response format');
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<List<AppointmentTypeReadDto>> _fetchAppointmentTypesRead() async {
    final response = await authService.authorizedRequest(
      "/appointment-types-read/",
      "GET",
    );

    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map(
              (e) =>
                  AppointmentTypeReadDto.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
      throw const ApiException(500, 'Unexpected response format');
    }

    throw ApiException(response.statusCode, response.body);
  }

  Future<DoctorHomeData> _loadHomeData() async {
    final generatedAtLocal = DateTime.now();

    // Window for analytics: last 30 days (inclusive) in local time.
    //  final toLocal = DateTime(
    //   generatedAtLocal.year,
    //   generatedAtLocal.month,
    //   generatedAtLocal.day,
    //   23,
    //   59,
    //   59,
    // );
    //  final fromLocal = toLocal.subtract(const Duration(days: 30));

    //  final fromYmd = _formatDateYmd(fromLocal);
    //  final toYmd = _formatDateYmd(toLocal);

    final results = await Future.wait([
      appointmentsService.fetchMyAppointments(preset: 'next7'),
      appointmentsService.fetchDoctorAbsences(),
      _fetchMyAvailabilities(),
      _fetchDoctorAppointmentTypes(),
      _fetchAppointmentTypesRead(),

      // Analytics source: all (we filter last 30 days locally)
      appointmentsService.fetchMyAppointments(time: 'all'),
    ]);

    final next7Appointments = results[0] as List<Appointment>;
    final absences = results[1] as List<DoctorAbsenceDto>;
    final availabilities = results[2] as List<DoctorAvailability>;
    final doctorAppointmentTypes = results[3] as List<DoctorAppointmentType>;
    final appointmentTypesRead = results[4] as List<AppointmentTypeReadDto>;
    final last30Appointments = results[5] as List<Appointment>;

    final slotMinutes = _chooseSlotMinutes(
      nowLocal: generatedAtLocal,
      daysCount: daysCount,
      appointments: next7Appointments,
      doctorOverrides: doctorAppointmentTypes,
      adminTypes: appointmentTypesRead,
      fallback: 15,
    );

    final analytics = computeDoctorAnalyticsLast30Days(
      last30Appointments,
      countOnlyActiveWork: false, // للتسليم: “ضغط/طلب” يشمل الملغي و no-show
    );

    return DoctorHomeData(
      appointments: next7Appointments,
      absences: absences,
      availabilities: availabilities,
      generatedAtLocal: generatedAtLocal,
      slotMinutes: slotMinutes,
      analytics: analytics,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      homeFuture = _loadHomeData();
    });

    try {
      await homeFuture;
    } catch (_) {
      // لا نعرض SnackBar هنا — AppFetchStateView كافي
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (userName ?? '').trim();
    final greeting = name.isNotEmpty ? 'أهلاً د. $name' : 'أهلاً بك';

    return FutureBuilder<DoctorHomeData>(
      future: homeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return AppFetchStateView(
            error: snapshot.error!,
            onRetry: () {
              setState(() {
                homeFuture = _loadHomeData();
              });
            },
          );
        }

        final data = snapshot.data!;
        if (widget.onAnalyticsLoaded != null) {
          final a = data.analytics;
          final shouldSend =
              _lastSentAnalytics == null ||
              _lastSentAnalytics!.fromLocal != a.fromLocal ||
              _lastSentAnalytics!.toLocal != a.toLocal ||
              _lastSentAnalytics!.totalAppointments != a.totalAppointments ||
              _lastSentAnalytics!.cancelledCount != a.cancelledCount ||
              _lastSentAnalytics!.noShowCount != a.noShowCount;

          if (shouldSend) {
            _lastSentAnalytics = a;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onAnalyticsLoaded?.call(a);
            });
          }
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    greeting,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'مواعيدك خلال الأيام السبعة القادمة.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DoctorWeekGrid(
                    nowLocal: data.generatedAtLocal,
                    appointments: data.appointments,
                    absences: data.absences,
                    availabilities: data.availabilities,
                    slotMinutes: data.slotMinutes,
                    daysCount: daysCount,
                  ),
                  const SizedBox(height: 14),
                  const _LegendRow(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Data container
// -----------------------------------------------------------------------------
class DoctorHomeData {
  final List<Appointment> appointments;
  final List<DoctorAbsenceDto> absences;
  final List<DoctorAvailability> availabilities;

  final DateTime generatedAtLocal;
  final int slotMinutes;

  final DoctorAnalytics analytics;

  DoctorHomeData({
    required this.appointments,
    required this.absences,
    required this.availabilities,
    required this.generatedAtLocal,
    required this.slotMinutes,
    required this.analytics,
  });
}

class AppointmentTypeReadDto {
  final int id;
  final int defaultDurationMinutes;
  final String typeName;

  AppointmentTypeReadDto({
    required this.id,
    required this.defaultDurationMinutes,
    required this.typeName,
  });

  factory AppointmentTypeReadDto.fromJson(Map<String, dynamic> json) {
    return AppointmentTypeReadDto(
      id: (json['id'] as num).toInt(),
      defaultDurationMinutes: (json['default_duration_minutes'] as num).toInt(),
      typeName: (json['type_name'] as String?) ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
// Slot minutes policy (dynamic, with safety caps)
// -----------------------------------------------------------------------------
int _chooseSlotMinutes({
  required DateTime nowLocal,
  required int daysCount,
  required List<Appointment> appointments,
  required List<DoctorAppointmentType> doctorOverrides,
  required List<AppointmentTypeReadDto> adminTypes,
  int fallback = 15,
}) {
  const allowed = <int>[5, 10, 15, 30];

  final startDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final endDayExclusive = startDay.add(Duration(days: daysCount));

  final appointmentDurations = <int>[];
  for (final ap in appointments) {
    final st = ap.status.trim().toLowerCase();
    if (st != 'pending' && st != 'confirmed') continue;

    final dt = ap.dateTime.toLocal();
    if (dt.isBefore(startDay) || !dt.isBefore(endDayExclusive)) continue;

    final d = ap.durationMinutes;
    if (d > 0) appointmentDurations.add(d);
  }

  List<int> pool = appointmentDurations;

  if (pool.isEmpty) {
    final tmp = <int>[];
    for (final o in doctorOverrides) {
      final d = o.durationMinutes;
      if (d > 0) tmp.add(d);
    }
    pool = tmp;
  }

  if (pool.isEmpty) {
    final tmp = <int>[];
    for (final t in adminTypes) {
      final d = t.defaultDurationMinutes;
      if (d > 0) tmp.add(d);
    }
    pool = tmp;
  }

  if (pool.isEmpty) return fallback;

  final minDur = pool.reduce((a, b) => a < b ? a : b);

  int candidate;
  if (minDur <= 5) {
    candidate = 5;
  } else if (minDur <= 10) {
    candidate = 10;
  } else if (minDur <= 15) {
    candidate = 15;
  } else {
    candidate = 30;
  }

  if (!allowed.contains(candidate)) candidate = fallback;

  if (candidate == 5 && minDur > 5) {
    candidate = 10;
  }

  return candidate;
}

// -----------------------------------------------------------------------------
// Grid logic
// -----------------------------------------------------------------------------
enum GridCellType { empty, pending, confirmed, absence, offDuty }

class DoctorWeekGrid extends StatelessWidget {
  final DateTime nowLocal;
  final List<Appointment> appointments;
  final List<DoctorAbsenceDto> absences;
  final List<DoctorAvailability> availabilities;
  final int slotMinutes;
  final int daysCount;

  const DoctorWeekGrid({
    super.key,
    required this.nowLocal,
    required this.appointments,
    required this.absences,
    required this.availabilities,
    required this.slotMinutes,
    required this.daysCount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final days = List<DateTime>.generate(daysCount, (i) {
      return DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
      ).add(Duration(days: i));
    });

    final relevantAppointments =
        appointments.where((ap) {
          final st = ap.status.trim().toLowerCase();
          return st == 'pending' || st == 'confirmed';
        }).toList();

    final dayRanges = _buildDayAvailabilityRanges(days, availabilities);

    final bounds = _computeBoundsFromAvailability(
      dayRanges,
      roundToMinutes: slotMinutes,
      minRows: 8,
      maxRows: 80,
      fallbackStart: 9 * 60,
      fallbackEnd: 17 * 60,
    );

    int startMinutes = bounds.startMinutes;
    int endMinutes = bounds.endMinutes;

    int effectiveSlot = slotMinutes;
    int rows = ((endMinutes - startMinutes) / effectiveSlot).ceil();
    if (rows > 80) {
      effectiveSlot = 15;
      startMinutes = (startMinutes ~/ effectiveSlot) * effectiveSlot;
      endMinutes =
          ((endMinutes + effectiveSlot - 1) ~/ effectiveSlot) * effectiveSlot;
      rows = ((endMinutes - startMinutes) / effectiveSlot).ceil();
      if (rows > 80) {
        effectiveSlot = 30;
        startMinutes = (startMinutes ~/ effectiveSlot) * effectiveSlot;
        endMinutes =
            ((endMinutes + effectiveSlot - 1) ~/ effectiveSlot) * effectiveSlot;
      }
    }

    final slots = <int>[];
    for (int m = startMinutes; m < endMinutes; m += effectiveSlot) {
      slots.add(m);
    }

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GridHeaderRow(days: days),
            const SizedBox(height: 8),
            ...slots.map((minuteOfDay) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _GridTimeRow(
                  days: days,
                  minuteOfDay: minuteOfDay,
                  slotMinutes: effectiveSlot,
                  appointments: relevantAppointments,
                  absences: absences,
                  dayRanges: dayRanges,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GridHeaderRow extends StatelessWidget {
  final List<DateTime> days;

  const _GridHeaderRow({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox(width: 56),
        ...List.generate(days.length, (i) {
          final d = days[i];
          final isTodayColumn = i == 0;

          final letter = _arabicWeekdayLetter(d.weekday);
          final dd = d.day.toString();

          final textColor =
              isTodayColumn ? cs.primary : cs.onSurface.withValues(alpha: 0.85);

          return Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                decoration:
                    isTodayColumn
                        ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.35),
                          ),
                          color: cs.primaryContainer.withValues(alpha: 0.25),
                        )
                        : null,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dd,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: textColor.withValues(alpha: 0.95),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  static String _arabicWeekdayLetter(int weekday) {
    // DateTime.weekday: Mon=1 ... Sun=7
    switch (weekday) {
      case 6: // Saturday
        return 'س';
      case 5: // Friday
        return 'ج';
      case 4: // Thursday
        return 'خ';
      case 3: // Wednesday
        return 'ر';
      case 2: // Tuesday
        return 'ث';
      case 1: // Monday
        return 'ن';
      case 7: // Sunday
      default:
        return 'ح';
    }
  }
}

class _GridTimeRow extends StatelessWidget {
  final List<DateTime> days;
  final int minuteOfDay;
  final int slotMinutes;
  final List<Appointment> appointments;
  final List<DoctorAbsenceDto> absences;
  final List<_DayAvailabilityRange> dayRanges;

  const _GridTimeRow({
    required this.days,
    required this.minuteOfDay,
    required this.slotMinutes,
    required this.appointments,
    required this.absences,
    required this.dayRanges,
  });

  @override
  Widget build(BuildContext context) {
    final label = _formatTime(minuteOfDay);

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.70),
            ),
          ),
        ),
        ...List.generate(days.length, (i) {
          final day = days[i];
          final isTodayColumn = i == 0;

          final slotStart = DateTime(
            day.year,
            day.month,
            day.day,
          ).add(Duration(minutes: minuteOfDay));
          final slotEnd = slotStart.add(Duration(minutes: slotMinutes));

          final range = dayRanges[i];
          final isWithinDuty = range.contains(slotStart, slotEnd);

          final type =
              isWithinDuty
                  ? _resolveCellType(
                    slotStart: slotStart,
                    slotEnd: slotEnd,
                    appointments: appointments,
                    absences: absences,
                  )
                  : GridCellType.offDuty;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _Cell(type: type, isTodayColumn: isTodayColumn),
            ),
          );
        }),
      ],
    );
  }

  static GridCellType _resolveCellType({
    required DateTime slotStart,
    required DateTime slotEnd,
    required List<Appointment> appointments,
    required List<DoctorAbsenceDto> absences,
  }) {
    bool overlaps(
      DateTime aStart,
      DateTime aEnd,
      DateTime bStart,
      DateTime bEnd,
    ) {
      return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
    }

    // 1) Absence (planned/emergency)
    for (final ab in absences) {
      final abStart = ab.startTime.toLocal();
      final abEnd = ab.endTime.toLocal();
      if (overlaps(slotStart, slotEnd, abStart, abEnd)) {
        return GridCellType.absence;
      }
    }

    // 2) Appointment confirmed/pending
    GridCellType best = GridCellType.empty;

    for (final ap in appointments) {
      final apStart = ap.dateTime.toLocal();

      final duration = ap.durationMinutes;
      final safeDuration = (duration > 0) ? duration : 10;

      final apEnd = apStart.add(Duration(minutes: safeDuration));

      if (!overlaps(slotStart, slotEnd, apStart, apEnd)) continue;

      final st = ap.status.trim().toLowerCase();
      if (st == 'confirmed') return GridCellType.confirmed;
      if (st == 'pending') best = GridCellType.pending;
    }

    return best;
  }

  static String _formatTime(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final m = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// -----------------------------------------------------------------------------
// Cell rendering (absence hatch + off-duty is blank)
// -----------------------------------------------------------------------------
class _Cell extends StatelessWidget {
  final GridCellType type;
  final bool isTodayColumn;

  const _Cell({required this.type, required this.isTodayColumn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // خارج الدوام: لا بطاقة ولا لون (فراغ فقط)
    if (type == GridCellType.offDuty) {
      return const SizedBox(height: 18);
    }

    final emptyFill = cs.surfaceContainerHighest.withValues(alpha: 0.14);

    Color fill;
    Color border;

    switch (type) {
      case GridCellType.absence:
        fill = cs.surfaceContainerHighest.withValues(alpha: 0.30);
        border = cs.outline.withValues(alpha: 0.18);
        break;

      case GridCellType.confirmed:
        fill = cs.primaryContainer.withValues(alpha: 0.95);
        border = cs.primary.withValues(alpha: 0.30);
        break;

      case GridCellType.pending:
        fill = cs.primaryContainer.withValues(alpha: 0.50);
        border = cs.primary.withValues(alpha: 0.25);
        break;

      case GridCellType.empty:
      default:
        fill = emptyFill;
        border = cs.outline.withValues(alpha: 0.14);
        break;
    }

    final todayBorder =
        isTodayColumn
            ? Border.all(color: cs.primary.withValues(alpha: 0.20), width: 1.1)
            : null;

    Widget wrapToday(Widget child) {
      if (todayBorder == null) return child;
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: todayBorder,
        ),
        padding: const EdgeInsets.all(1),
        child: child,
      );
    }

    if (type != GridCellType.absence) {
      return wrapToday(
        Container(
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border),
          ),
        ),
      );
    }

    // Absence = hatch
    return wrapToday(
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _HatchPainter(
            lineColor: cs.onSurface.withValues(alpha: 0.22),
            background: fill,
          ),
          child: const SizedBox(height: 18),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  final Color lineColor;
  final Color background;

  _HatchPainter({required this.lineColor, required this.background});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = background;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final paint =
        Paint()
          ..color = lineColor
          ..strokeWidth = 1;

    const gap = 6.0;
    for (double x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HatchPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.background != background;
  }
}

// -----------------------------------------------------------------------------
// Legend
// -----------------------------------------------------------------------------
class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget item(Widget swatch, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    final hatchSwatch = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CustomPaint(
        painter: _HatchPainter(
          lineColor: cs.onSurface.withValues(alpha: 0.22),
          background: cs.surfaceContainerHighest.withValues(alpha: 0.30),
        ),
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );

    Widget solid(Color c) => Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        item(hatchSwatch, 'غياب'),
        item(solid(cs.primaryContainer.withValues(alpha: 0.95)), 'مؤكد'),
        item(
          solid(cs.primaryContainer.withValues(alpha: 0.50)),
          'بانتظار التأكيد',
        ),
        item(solid(cs.surfaceContainerHighest.withValues(alpha: 0.14)), 'فارغ'),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Availability ranges and bounds
// -----------------------------------------------------------------------------
class _DayAvailabilityRange {
  final DateTime day;
  final int? startMinute; // null = no duty
  final int? endMinute;

  const _DayAvailabilityRange({
    required this.day,
    required this.startMinute,
    required this.endMinute,
  });

  bool contains(DateTime slotStart, DateTime slotEnd) {
    if (startMinute == null || endMinute == null) return false;
    final start = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: startMinute!));
    final end = DateTime(
      day.year,
      day.month,
      day.day,
    ).add(Duration(minutes: endMinute!));
    return slotStart.isBefore(end) && slotEnd.isAfter(start);
  }
}

List<_DayAvailabilityRange> _buildDayAvailabilityRanges(
  List<DateTime> days,
  List<DoctorAvailability> availabilities,
) {
  String normalize(String s) => s.trim().toLowerCase();

  bool matchesDay(String dayOfWeekValue, int dartWeekday) {
    final v = normalize(dayOfWeekValue);

    final asInt = int.tryParse(v);
    if (asInt != null) {
      if (asInt >= 1 && asInt <= 7) return asInt == dartWeekday;
      if (asInt >= 0 && asInt <= 6) {
        final mapped = asInt == 0 ? 7 : asInt;
        return mapped == dartWeekday;
      }
    }

    if (v.startsWith('mon')) return dartWeekday == 1;
    if (v.startsWith('tue')) return dartWeekday == 2;
    if (v.startsWith('wed')) return dartWeekday == 3;
    if (v.startsWith('thu')) return dartWeekday == 4;
    if (v.startsWith('fri')) return dartWeekday == 5;
    if (v.startsWith('sat')) return dartWeekday == 6;
    if (v.startsWith('sun')) return dartWeekday == 7;

    if (v.contains('الاثنين') || v == 'ن') return dartWeekday == 1;
    if (v.contains('الثلاث') || v == 'ث') return dartWeekday == 2;
    if (v.contains('الأربع') || v == 'ر') return dartWeekday == 3;
    if (v.contains('الخميس') || v == 'خ') return dartWeekday == 4;
    if (v.contains('الجمعة') || v == 'ج') return dartWeekday == 5;
    if (v.contains('السبت') || v == 'س') return dartWeekday == 6;
    if (v.contains('الأحد') || v == 'ح') return dartWeekday == 7;

    return false;
  }

  int? parseTimeToMinute(String hhmmss) {
    final t = hhmmss.trim();
    if (t.isEmpty) return null;

    final parts = t.split(':');
    if (parts.length < 2) return null;

    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;

    return h * 60 + m;
  }

  final ranges = <_DayAvailabilityRange>[];

  for (final day in days) {
    final dayAvs =
        availabilities
            .where((a) => matchesDay(a.dayOfWeek, day.weekday))
            .toList();

    if (dayAvs.isEmpty) {
      ranges.add(
        _DayAvailabilityRange(day: day, startMinute: null, endMinute: null),
      );
      continue;
    }

    int? minStart;
    int? maxEnd;

    for (final a in dayAvs) {
      final s = parseTimeToMinute(a.startTime);
      final e = parseTimeToMinute(a.endTime);
      if (s == null || e == null) continue;

      minStart = (minStart == null) ? s : (s < minStart ? s : minStart);
      maxEnd = (maxEnd == null) ? e : (e > maxEnd ? e : maxEnd);
    }

    ranges.add(
      _DayAvailabilityRange(day: day, startMinute: minStart, endMinute: maxEnd),
    );
  }

  return ranges;
}

class _TimeBounds {
  final int startMinutes;
  final int endMinutes;

  const _TimeBounds({required this.startMinutes, required this.endMinutes});
}

_TimeBounds _computeBoundsFromAvailability(
  List<_DayAvailabilityRange> dayRanges, {
  required int roundToMinutes,
  required int minRows,
  required int maxRows,
  required int fallbackStart,
  required int fallbackEnd,
}) {
  int? minStart;
  int? maxEnd;

  for (final r in dayRanges) {
    if (r.startMinute == null || r.endMinute == null) continue;
    minStart =
        (minStart == null)
            ? r.startMinute
            : (r.startMinute! < minStart ? r.startMinute : minStart);
    maxEnd =
        (maxEnd == null)
            ? r.endMinute
            : (r.endMinute! > maxEnd ? r.endMinute : maxEnd);
  }

  int start = minStart ?? fallbackStart;
  int end = maxEnd ?? fallbackEnd;

  final minDuration = minRows * roundToMinutes;
  if (end - start < minDuration) {
    end = start + minDuration;
  }

  start = (start ~/ roundToMinutes) * roundToMinutes;
  end = ((end + roundToMinutes - 1) ~/ roundToMinutes) * roundToMinutes;

  const minClamp = 6 * 60;
  const maxClamp = 22 * 60;
  if (start < minClamp) start = minClamp;
  if (end > maxClamp) end = maxClamp;

  final rows = ((end - start) / roundToMinutes).ceil();
  if (rows > maxRows) {
    end = start + (maxRows * roundToMinutes);
    if (end > maxClamp) end = maxClamp;
  }

  return _TimeBounds(startMinutes: start, endMinutes: end);
}
