import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/cardio_service.dart';
import 'package:foco_academia_mobile/services/outdoor_consistency.dart';

CardioSession _session({
  required DateTime completedAt,
  double meters = 2000,
}) {
  return CardioSession(
    id: completedAt.toIso8601String(),
    completedAt: completedAt,
    startedAt: completedAt.subtract(const Duration(minutes: 30)),
    distanceMeters: meters,
    caloriesKcal: 120,
  );
}

void main() {
  test('marca Seg–Dom com feitos e falhas nesta semana', () {
    // Quarta-feira 15/jul/2026
    final now = DateTime(2026, 7, 15);
    final summary = OutdoorConsistency.fromSessions(
      [
        _session(completedAt: DateTime(2026, 7, 13)), // Seg
        _session(completedAt: DateTime(2026, 7, 14)), // Ter
        // Qua (hoje) ainda sem treino — não é falha
        // Qui/Sex/Sáb/Dom futuros
      ],
      now: now,
    );

    expect(summary.thisWeek.length, 7);
    expect(summary.thisWeek.first.shortLabel, 'Seg');
    expect(summary.thisWeek.first.walked, isTrue);
    expect(summary.thisWeek[1].walked, isTrue);
    expect(summary.thisWeek[2].isToday, isTrue);
    expect(summary.thisWeek[2].missed, isFalse);
    expect(summary.thisWeek[2].walked, isFalse);

    // Segunda e terça feitos; nenhum passado sem treino além disso.
    expect(summary.daysWalkedThisWeek, 2);
    expect(summary.daysMissedThisWeek, 0);
  });

  test('conta falha em dia passado sem caminhada', () {
    final now = DateTime(2026, 7, 15); // Qua
    final summary = OutdoorConsistency.fromSessions(
      [
        _session(completedAt: DateTime(2026, 7, 13)), // só Seg
      ],
      now: now,
    );
    expect(summary.daysWalkedThisWeek, 1);
    expect(summary.daysMissedThisWeek, 1); // Terça
    expect(summary.thisWeek[1].missed, isTrue);
    expect(summary.thisWeek[1].shortLabel, 'Ter');
  });

  test('sequência outdoor só com dias consecutivos', () {
    final now = DateTime(2026, 7, 15);
    final summary = OutdoorConsistency.fromSessions(
      [
        _session(completedAt: DateTime(2026, 7, 13)),
        _session(completedAt: DateTime(2026, 7, 14)),
        _session(completedAt: DateTime(2026, 7, 15)),
      ],
      now: now,
    );
    expect(summary.currentStreakDays, 3);
    expect(summary.bestStreakDays, greaterThanOrEqualTo(3));
    expect(summary.monthWalkedCount, 3);
  });

  test('ignora sessão sem distância e sem tempo relevante', () {
    final now = DateTime(2026, 7, 15);
    final summary = OutdoorConsistency.fromSessions(
      [
        const CardioSession(
          id: 'curta',
          completedAt: null,
          startedAt: null,
          distanceMeters: 10,
          elapsedMs: 5000,
        ),
        CardioSession(
          id: 'ok',
          completedAt: DateTime(2026, 7, 14, 18),
          distanceMeters: 10,
          elapsedMs: 5 * 60 * 1000,
        ),
      ],
      now: now,
      minDistanceMeters: 50,
    );
    // Sem completedAt/startedAt → ignora; a segunda tem tempo ≥ 1 min → conta.
    expect(summary.daysWalkedThisWeek, 1);
  });
}
