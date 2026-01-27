import '/models/appointment.dart';

class DoctorAnalytics {
  final DateTime fromLocal;
  final DateTime toLocal;

  final int totalAppointments;
  final int cancelledCount;
  final int noShowCount;

  /// 0..100 (rounded)
  final int cancellationRatePct;

  /// 0..100 (rounded)
  final int noShowRatePct;

  /// key = hour (0..23), value = count
  final Map<int, int> peakHoursCounts;

  DoctorAnalytics({
    required this.fromLocal,
    required this.toLocal,
    required this.totalAppointments,
    required this.cancelledCount,
    required this.noShowCount,
    required this.cancellationRatePct,
    required this.noShowRatePct,
    required this.peakHoursCounts,
  });

  int countAtHour(int hour) => peakHoursCounts[hour] ?? 0;

  int get maxHourCount {
    int maxV = 0;
    for (final v in peakHoursCounts.values) {
      if (v > maxV) maxV = v;
    }
    return maxV;
  }

  List<int> get sortedHoursAsc {
    final keys = peakHoursCounts.keys.toList()..sort();
    return keys;
  }
}

///
/// Policy choice:
/// - By default peak hours counts ALL appointments (including cancelled/no_show)
///   as "demand/traffic".
/// - If we want peak hours for "active work only", set [countOnlyActiveWork] = true.
///
DoctorAnalytics computeDoctorAnalyticsLast30Days(
  List<Appointment> appointments, {
  bool countOnlyActiveWork = false, // pending/confirmed only
}) {
  final now = DateTime.now();

  // Last 30 days window in LOCAL time
  final toLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final fromLocal = toLocal.subtract(const Duration(days: 30));

  bool inRange(DateTime dtLocal) {
    final afterFrom =
        dtLocal.isAfter(fromLocal) || dtLocal.isAtSameMomentAs(fromLocal);
    final beforeTo =
        dtLocal.isBefore(toLocal) || dtLocal.isAtSameMomentAs(toLocal);
    return afterFrom && beforeTo;
  }

  String norm(String s) => s.trim().toLowerCase();

  final inWindow = <Appointment>[];
  for (final ap in appointments) {
    final dtLocal = ap.dateTime.toLocal();
    if (inRange(dtLocal)) inWindow.add(ap);
  }

  final total = inWindow.length;

  int cancelled = 0;
  int noShow = 0;

  final Map<int, int> byHour = <int, int>{};

  for (final ap in inWindow) {
    final st = norm(ap.status);

    if (st == 'cancelled') cancelled++;
    if (st == 'no_show') noShow++;

    if (countOnlyActiveWork) {
      if (st != 'pending' && st != 'confirmed') continue;
    }

    final hour = ap.dateTime.toLocal().hour;
    byHour[hour] = (byHour[hour] ?? 0) + 1;
  }

  int pct(int part, int whole) {
    if (whole <= 0) return 0;
    return ((part * 100) / whole).round();
  }

  return DoctorAnalytics(
    fromLocal: fromLocal,
    toLocal: toLocal,
    totalAppointments: total,
    cancelledCount: cancelled,
    noShowCount: noShow,
    cancellationRatePct: pct(cancelled, total),
    noShowRatePct: pct(noShow, total),
    peakHoursCounts: byHour,
  );
}
