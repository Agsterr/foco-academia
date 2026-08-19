import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/looping_intervals.dart';
import 'package:foco_academia_mobile/services/outdoor_goal.dart';

void main() {
  test('phaseAt alterna caminhada e corrida', () {
    final walk =
        LoopingIntervals.phaseAt(elapsedSec: 30, walkSec: 120, runSec: 120);
    expect(walk.isRun, isFalse);
    final run =
        LoopingIntervals.phaseAt(elapsedSec: 150, walkSec: 120, runSec: 120);
    expect(run.isRun, isTrue);
    final walk2 =
        LoopingIntervals.phaseAt(elapsedSec: 240, walkSec: 120, runSec: 120);
    expect(walk2.isRun, isFalse);
  });

  test('remainingSec conta o que falta na fase', () {
    expect(
      LoopingIntervals.remainingSec(elapsedSec: 30, walkSec: 120, runSec: 60),
      90,
    );
    expect(
      LoopingIntervals.remainingSec(elapsedSec: 130, walkSec: 120, runSec: 60),
      50,
    );
  });

  test('estimatedRoundsForKm cresce com a meta', () {
    final r5 = LoopingIntervals.estimatedRoundsForKm(
      targetKm: 5,
      walkSec: 120,
      runSec: 120,
    );
    final r75 = LoopingIntervals.estimatedRoundsForKm(
      targetKm: 7.5,
      walkSec: 120,
      runSec: 120,
    );
    final r10 = LoopingIntervals.estimatedRoundsForKm(
      targetKm: 10,
      walkSec: 120,
      runSec: 120,
    );
    expect(r10, greaterThan(r5));
    expect(r75, greaterThanOrEqualTo(r5));
    expect(r75, lessThanOrEqualTo(r10));
    expect(r5, greaterThanOrEqualTo(1));
  });

  test('OutdoorGoal intervalado tem meta numérica', () {
    expect(
      const OutdoorGoal(
        mode: OutdoorGoalMode.intervals,
        walkMin: 2,
        runMin: 2,
        targetKm: 5,
      ).hasNumericTarget,
      isTrue,
    );
    expect(
      const OutdoorGoal(
        mode: OutdoorGoalMode.intervals,
        targetMinutes: 60,
      ).hasNumericTarget,
      isTrue,
    );
  });
}
