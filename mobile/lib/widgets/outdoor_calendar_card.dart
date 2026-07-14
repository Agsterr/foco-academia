import 'package:flutter/material.dart';

import '../services/outdoor_consistency.dart';

/// Calendário outdoor: semana Seg–Dom + mês, com constância e falhas.
class OutdoorCalendarCard extends StatelessWidget {
  const OutdoorCalendarCard({super.key, required this.summary});

  final OutdoorConsistencySummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calendário de caminhadas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _weekHeadline(),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '${summary.daysWalkedThisWeek}/7',
                  label: 'esta semana',
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  value: '${summary.daysMissedThisWeek}',
                  label: 'falhas',
                  color: summary.daysMissedThisWeek > 0
                      ? Colors.orangeAccent
                      : Colors.white54,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  value: '${summary.currentStreakDays}',
                  label: 'sequência',
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Esta semana',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: summary.thisWeek
                .map((d) => Expanded(child: _WeekDayCell(day: d)))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF22C55E), label: 'Fez'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFFF97316), label: 'Falhou'),
              SizedBox(width: 12),
              _LegendDot(color: Color(0xFF3F3F46), label: 'Ainda não'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            summary.monthLabel,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            '${summary.monthWalkedCount} dia${summary.monthWalkedCount == 1 ? '' : 's'} com outdoor neste mês',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          _MonthGrid(days: summary.monthDays),
        ],
      ),
    );
  }

  String _weekHeadline() {
    final w = summary.daysWalkedThisWeek;
    final m = summary.daysMissedThisWeek;
    if (w == 0 && m == 0) {
      return 'Marque os dias em que você caminhou ou correu.';
    }
    if (m == 0) {
      return 'Constância em dia: $w dia${w == 1 ? '' : 's'} esta semana.';
    }
    return '$w dia${w == 1 ? '' : 's'} feitos · $m falha${m == 1 ? '' : 's'} esta semana.';
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({required this.day});

  final OutdoorWeekDayStatus day;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (day.walked) {
      bg = const Color(0xFF166534);
      fg = Colors.greenAccent;
    } else if (day.missed) {
      bg = const Color(0xFF7C2D12);
      fg = Colors.orangeAccent;
    } else if (day.isToday) {
      bg = const Color(0xFF1E3A5F);
      fg = Colors.lightBlueAccent;
    } else {
      bg = const Color(0xFF27272A);
      fg = Colors.white38;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Text(
            day.shortLabel,
            style: TextStyle(
              fontSize: 11,
              color: day.isToday ? Colors.white : Colors.white54,
              fontWeight: day.isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: day.isToday
                  ? Border.all(color: Colors.lightBlueAccent, width: 1.2)
                  : null,
            ),
            child: Text(
              '${day.date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: fg,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day.walked ? '${day.km.toStringAsFixed(1)}' : '—',
            style: TextStyle(
              fontSize: 9,
              color: day.walked ? Colors.white70 : Colors.white24,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.days});

  final List<OutdoorMonthDay> days;

  @override
  Widget build(BuildContext context) {
    final headers = OutdoorConsistency.weekDayShort.values.toList();
    return Column(
      children: [
        Row(
          children: headers
              .map(
                (h) => Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < days.length; row += 7)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var i = row; i < row + 7 && i < days.length; i++)
                  Expanded(child: _MonthCell(day: days[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({required this.day});

  final OutdoorMonthDay day;

  @override
  Widget build(BuildContext context) {
    if (!day.inMonth) {
      return const SizedBox(height: 28);
    }
    final walked = day.walked;
    return Container(
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: walked
            ? const Color(0xFF166534)
            : day.isToday
                ? const Color(0xFF1E3A5F)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: day.isToday
            ? Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.7))
            : null,
      ),
      child: Text(
        '${day.date.day}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: walked || day.isToday ? FontWeight.w700 : FontWeight.w400,
          color: walked
              ? Colors.greenAccent
              : day.inMonth
                  ? Colors.white54
                  : Colors.white24,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }
}
