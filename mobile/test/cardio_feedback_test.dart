import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/cardio_feedback.dart';

void main() {
  test('phaseSpeechLabel retorna Corrida ou Caminhada', () {
    expect(CardioFeedback.phaseSpeechLabel('RUN'), 'Corrida');
    expect(CardioFeedback.phaseSpeechLabel('run'), 'Corrida');
    expect(CardioFeedback.phaseSpeechLabel('WALK'), 'Caminhada');
    expect(CardioFeedback.phaseSpeechLabel('walk'), 'Caminhada');
  });

  test('phaseVibrationPattern usa 2 pulsos para corrida e 1 para caminhada', () {
    final run = CardioFeedback.phaseVibrationPattern('RUN');
    final walk = CardioFeedback.phaseVibrationPattern('WALK');

    expect(run, CardioFeedback.runVibrationPattern);
    expect(walk, CardioFeedback.walkVibrationPattern);
    expect(run.where((n) => n >= 400), isNotEmpty);
    expect(walk.length, 2);
    expect(run.length, 4);
  });
}
