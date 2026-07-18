import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/cardio_service.dart';

void main() {
  test('parseIntervals lê JSON string do coach', () {
    const raw =
        '[{"phase":"WALK","durationSec":120},{"phase":"RUN","durationSec":180},'
        '{"phase":"WALK","durationSec":120},{"phase":"RUN","durationSec":180}]';
    final intervals = parseIntervals(raw);
    expect(intervals, hasLength(4));
    expect(intervals[0].phase, 'WALK');
    expect(intervals[0].durationSec, 120);
    expect(intervals[1].phase, 'RUN');
    expect(intervals[1].durationSec, 180);
  });

  test('parseIntervals aceita lista já decodificada', () {
    final intervals = parseIntervals([
      {'phase': 'WALK', 'durationSec': 120},
      {'phase': 'RUN', 'durationSec': 180},
    ]);
    expect(intervals, hasLength(2));
    expect(intervals.first.isRun, isFalse);
    expect(intervals.last.isRun, isTrue);
  });

  test('parseIntervals ignora payload inválido', () {
    expect(parseIntervals(null), isEmpty);
    expect(parseIntervals(''), isEmpty);
    expect(parseIntervals('{broken'), isEmpty);
    expect(parseIntervals({'phase': 'WALK'}), isEmpty);
  });

  test('summarizeIntervals mostra caminhada + corrida + rodadas', () {
    final intervals = parseIntervals([
      {'phase': 'WALK', 'durationSec': 120},
      {'phase': 'RUN', 'durationSec': 180},
      {'phase': 'WALK', 'durationSec': 120},
      {'phase': 'RUN', 'durationSec': 180},
    ]);
    expect(
      summarizeIntervals(intervals),
      '2 min caminhada + 3 min corrida · 2 rodadas',
    );
  });

  test('CardioWorkout.fromJson preenche intervals a partir de intervalsJson', () {
    final workout = CardioWorkout.fromJson({
      'id': 'w1',
      'title': 'Intervalado',
      'type': 'INTERVAL',
      'intervalsJson':
          '[{"phase":"WALK","durationSec":120},{"phase":"RUN","durationSec":180}]',
    });
    expect(workout.intervals, hasLength(2));
    expect(workout.intervalsSummary, '2 min caminhada + 3 min corrida');
  });
}
