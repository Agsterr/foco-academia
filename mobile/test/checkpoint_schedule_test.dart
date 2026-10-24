import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/checkpoint_schedule.dart';

void main() {
  test('salva a cada 10 s mesmo quando o relógio pula os segundos redondos', () {
    // Com a tela apagada os ticks chegam a cada ~7 s: 7, 14, 21, 28...
    int? last;
    final saves = <int>[];
    for (var t = 7; t <= 70; t += 7) {
      if (checkpointDue(lastSec: last, nowSec: t, everySec: 10)) {
        last = t;
        saves.add(t);
      }
    }
    // A regra antiga (t % 10 == 0) só salvaria em 70.
    expect(saves, [14, 28, 42, 56, 70]);
  });

  test('não salva antes do primeiro intervalo nem com tempo zerado', () {
    expect(checkpointDue(lastSec: null, nowSec: 0, everySec: 10), isFalse);
    expect(checkpointDue(lastSec: null, nowSec: 9, everySec: 10), isFalse);
    expect(checkpointDue(lastSec: null, nowSec: 10, everySec: 10), isTrue);
    expect(checkpointDue(lastSec: 20, nowSec: 25, everySec: 10), isFalse);
  });

  test('treino retomado com tempo menor que o último save volta a salvar', () {
    expect(checkpointDue(lastSec: 500, nowSec: 12, everySec: 10), isTrue);
  });
}
