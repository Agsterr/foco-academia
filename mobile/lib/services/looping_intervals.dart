import 'cardio_service.dart';

/// Intervalado do aluno: N min caminhando + M min correndo, repetido
/// até bater a distância (km) ou o tempo (min) escolhidos.
class LoopingIntervals {
  LoopingIntervals._();

  static CardioInterval phaseAt({
    required int elapsedSec,
    required int walkSec,
    required int runSec,
  }) {
    final cycle = walkSec + runSec;
    if (cycle <= 0) {
      return const CardioInterval(phase: 'WALK', durationSec: 60);
    }
    final pos = elapsedSec % cycle;
    if (pos < walkSec) {
      return CardioInterval(phase: 'WALK', durationSec: walkSec);
    }
    return CardioInterval(phase: 'RUN', durationSec: runSec);
  }

  static int remainingSec({
    required int elapsedSec,
    required int walkSec,
    required int runSec,
  }) {
    final cycle = walkSec + runSec;
    if (cycle <= 0) return 0;
    final pos = elapsedSec % cycle;
    if (pos < walkSec) return walkSec - pos;
    return cycle - pos;
  }

  static int estimatedRoundsForKm({
    required double targetKm,
    required int walkSec,
    required int runSec,
    double walkKmh = 5.0,
    double runKmh = 9.0,
  }) {
    final walkKm = walkKmh * (walkSec / 3600.0);
    final runKm = runKmh * (runSec / 3600.0);
    final cycleKm = walkKm + runKm;
    if (cycleKm <= 0 || targetKm <= 0) return 1;
    return (targetKm / cycleKm).ceil().clamp(1, 200);
  }

  static int estimatedRoundsForMinutes({
    required int targetMin,
    required int walkSec,
    required int runSec,
  }) {
    final cycleSec = walkSec + runSec;
    if (cycleSec <= 0 || targetMin <= 0) return 1;
    return ((targetMin * 60) / cycleSec).ceil().clamp(1, 200);
  }
}
