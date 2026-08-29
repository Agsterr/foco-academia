import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/interval_duration.dart';

void main() {
  test('parseInput aceita minutos decimais', () {
    expect(IntervalDuration.parseInput('2.5'), 150);
    expect(IntervalDuration.parseInput('2,5'), 150);
    expect(IntervalDuration.parseInput('1.5'), 90);
  });

  test('parseInput aceita mm:ss e mm.ss', () {
    expect(IntervalDuration.parseInput('1:30'), 90);
    expect(IntervalDuration.parseInput('1.30'), 90);
    expect(IntervalDuration.parseInput('2:00'), 120);
  });

  test('parseInput não transforma 2.5 em 25', () {
    expect(IntervalDuration.parseInput('2.5'), isNot(25 * 60));
    expect(IntervalDuration.parseInput('2.5'), 150);
  });

  test('step ajusta de 30 em 30 segundos', () {
    expect(IntervalDuration.step(120, direction: 1), 150);
    expect(IntervalDuration.step(120, direction: -1), 90);
    expect(IntervalDuration.step(30, direction: -1), 30);
  });

  test('format exibe m:ss', () {
    expect(IntervalDuration.format(150), '2:30');
    expect(IntervalDuration.format(90), '1:30');
    expect(IntervalDuration.format(120), '2:00');
  });
}
