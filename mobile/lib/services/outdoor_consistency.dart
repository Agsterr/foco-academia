import '../services/cardio_service.dart';

/// Dia da semana no calendário outdoor (Seg → Dom).
class OutdoorWeekDayStatus {
  const OutdoorWeekDayStatus({
    required this.date,
    required this.weekDayKey,
    required this.shortLabel,
    required this.walked,
    required this.km,
    required this.isToday,
    required this.isFuture,
    required this.missed,
  });

  final DateTime date;
  final String weekDayKey;
  final String shortLabel;
  final bool walked;
  final double km;
  final bool isToday;
  final bool isFuture;
  /// Dia passado desta semana sem caminhada/corrida.
  final bool missed;
}

class OutdoorMonthDay {
  const OutdoorMonthDay({
    required this.date,
    required this.walked,
    required this.km,
    required this.inMonth,
    required this.isToday,
  });

  final DateTime date;
  final bool walked;
  final double km;
  final bool inMonth;
  final bool isToday;
}

/// Resumo de constância outdoor (só caminhada/corrida, sem musculação).
class OutdoorConsistencySummary {
  const OutdoorConsistencySummary({
    required this.walkedDates,
    required this.kmByDate,
    required this.thisWeek,
    required this.daysWalkedThisWeek,
    required this.daysMissedThisWeek,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.monthDays,
    required this.monthWalkedCount,
    required this.monthLabel,
  });

  final Set<String> walkedDates;
  final Map<String, double> kmByDate;
  final List<OutdoorWeekDayStatus> thisWeek;
  final int daysWalkedThisWeek;
  final int daysMissedThisWeek;
  final int currentStreakDays;
  final int bestStreakDays;
  final List<OutdoorMonthDay> monthDays;
  final int monthWalkedCount;
  final String monthLabel;

  double get weekAdherence {
    final due = daysWalkedThisWeek + daysMissedThisWeek;
    if (due <= 0) return daysWalkedThisWeek > 0 ? 1 : 0;
    return daysWalkedThisWeek / due;
  }
}

/// Calcula calendário / sequência a partir das sessões outdoor concluídas.
class OutdoorConsistency {
  OutdoorConsistency._();

  static const weekDayKeys = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  static const weekDayShort = {
    'MONDAY': 'Seg',
    'TUESDAY': 'Ter',
    'WEDNESDAY': 'Qua',
    'THURSDAY': 'Qui',
    'FRIDAY': 'Sex',
    'SATURDAY': 'Sáb',
    'SUNDAY': 'Dom',
  };

  static const _monthNames = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static String dateKey(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String weekDayKeyFromDate(DateTime d) => weekDayKeys[d.weekday - 1];

  static OutdoorConsistencySummary fromSessions(
    List<CardioSession> sessions, {
    DateTime? now,
    double minDistanceMeters = 50,
  }) {
    final today = dateOnly(now ?? DateTime.now());
    final kmByDate = <String, double>{};

    for (final s in sessions) {
      final when = s.completedAt ?? s.startedAt;
      if (when == null) continue;
      final meters = s.distanceMeters ?? 0;
      if (meters < minDistanceMeters && (s.elapsedMs ?? 0) < 60 * 1000) {
        continue;
      }
      final key = dateKey(when.toLocal());
      kmByDate[key] = (kmByDate[key] ?? 0) + (meters / 1000.0);
    }

    final walked = kmByDate.keys.toSet();
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final thisWeek = <OutdoorWeekDayStatus>[];
    var walkedWeek = 0;
    var missedWeek = 0;

    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final key = dateKey(day);
      final wd = weekDayKeyFromDate(day);
      final has = walked.contains(key);
      final future = day.isAfter(today);
      final isToday = day == today;
      final missed = !has && !future && !isToday;
      if (has) walkedWeek++;
      if (missed) missedWeek++;
      // Hoje sem treino ainda não conta como falha.
      thisWeek.add(
        OutdoorWeekDayStatus(
          date: day,
          weekDayKey: wd,
          shortLabel: weekDayShort[wd] ?? wd,
          walked: has,
          km: kmByDate[key] ?? 0,
          isToday: isToday,
          isFuture: future,
          missed: missed,
        ),
      );
    }

    final streak = _streaks(walked, today);

    final monthStart = DateTime(today.year, today.month, 1);
    final nextMonth = DateTime(today.year, today.month + 1, 1);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    final lastOfMonth = nextMonth.subtract(const Duration(days: 1));
    final gridEnd = lastOfMonth.add(Duration(days: 7 - lastOfMonth.weekday));
    final monthDays = <OutdoorMonthDay>[];
    var monthWalked = 0;
    for (var day = gridStart;
        !day.isAfter(gridEnd);
        day = day.add(const Duration(days: 1))) {
      final key = dateKey(day);
      final inMonth = day.month == today.month;
      final has = walked.contains(key);
      if (inMonth && has) monthWalked++;
      monthDays.add(
        OutdoorMonthDay(
          date: day,
          walked: has,
          km: kmByDate[key] ?? 0,
          inMonth: inMonth,
          isToday: day == today,
        ),
      );
    }

    return OutdoorConsistencySummary(
      walkedDates: walked,
      kmByDate: kmByDate,
      thisWeek: thisWeek,
      daysWalkedThisWeek: walkedWeek,
      daysMissedThisWeek: missedWeek,
      currentStreakDays: streak.current,
      bestStreakDays: streak.best,
      monthDays: monthDays,
      monthWalkedCount: monthWalked,
      monthLabel: '${_monthNames[today.month - 1]} ${today.year}',
    );
  }

  static ({int current, int best}) _streaks(Set<String> walked, DateTime today) {
    if (walked.isEmpty) return (current: 0, best: 0);

    var best = 0;
    var run = 0;
    // Percorre do dia mais antigo ao mais recente entre walked ± folga.
    final sorted = walked.map(DateTime.parse).toList()..sort();
    DateTime? prev;
    for (final d in sorted) {
      final day = dateOnly(d);
      if (prev == null || day.difference(prev).inDays == 1) {
        run++;
      } else if (day != prev) {
        run = 1;
      }
      if (run > best) best = run;
      prev = day;
    }

    var current = 0;
    var cursor = today;
    // Sequência atual: conta dias seguidos até ontem/hoje.
    if (!walked.contains(dateKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (walked.contains(dateKey(cursor))) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return (current: current, best: best);
  }
}
