import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/calorie_estimator.dart';
import 'package:foco_academia_mobile/services/outdoor_goal.dart';

void main() {
  test('kmForTargetCalories usa peso real do atleta', () {
    final km70 = CalorieEstimator.kmForTargetCalories(
      weightKg: 70,
      targetKcal: 400,
    );
    final km79 = CalorieEstimator.kmForTargetCalories(
      weightKg: 79,
      targetKcal: 400,
    );
    expect(km79, lessThan(km70));
    expect(km70, greaterThan(4));
    expect(km70, lessThan(8));
  });

  test('OutdoorGoal distingue metas numéricas', () {
    expect(
      const OutdoorGoal(mode: OutdoorGoalMode.distanceKm, targetKm: 5)
          .hasNumericTarget,
      isTrue,
    );
    expect(
      const OutdoorGoal(mode: OutdoorGoalMode.caloriesKcal, targetKcal: 400)
          .hasNumericTarget,
      isTrue,
    );
    expect(const OutdoorGoal().hasNumericTarget, isFalse);
  });

  test('formatKm não arredonda 7.5 para 8 nem esconde decimais', () {
    expect(OutdoorGoal.formatKm(5), '5');
    expect(OutdoorGoal.formatKm(7.5), '7.5');
    expect(OutdoorGoal.formatKm(3.25), '3.25');
    expect(OutdoorGoal.formatKm(10.0), '10');
  });

  test('intervalado aceita km personalizado', () {
    const goal = OutdoorGoal(
      mode: OutdoorGoalMode.intervals,
      walkMin: 3,
      runMin: 1,
      targetKm: 7.5,
    );
    expect(goal.hasNumericTarget, isTrue);
    expect(goal.label, contains('7.5 km'));
    expect(goal.label, isNot(contains('até 8 km')));
  });

  test('intervalado aceita tempo personalizado', () {
    const goal = OutdoorGoal(
      mode: OutdoorGoalMode.intervals,
      targetMinutes: 40,
    );
    expect(goal.hasNumericTarget, isTrue);
    expect(goal.label, contains('40 min'));
  });
}
