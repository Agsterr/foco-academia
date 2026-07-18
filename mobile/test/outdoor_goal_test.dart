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
      const OutdoorGoal(mode: OutdoorGoalMode.distanceKm, targetKm: 5).hasNumericTarget,
      isTrue,
    );
    expect(
      const OutdoorGoal(mode: OutdoorGoalMode.caloriesKcal, targetKcal: 400)
          .hasNumericTarget,
      isTrue,
    );
    expect(const OutdoorGoal().hasNumericTarget, isFalse);
  });
}
