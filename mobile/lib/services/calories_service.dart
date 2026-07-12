import 'calorie_estimator.dart';

/// Estimativa de calorias (MET) — fachada Fase 1.
class CaloriesService {
  CaloriesService._();
  static final instance = CaloriesService._();

  double resolveWeight(double? kg) => CalorieEstimator.resolveWeight(kg);

  int cardioKcal({
    required double weightKg,
    required double avgSpeedKmh,
    required int elapsedMs,
    double? distanceMeters,
  }) {
    return CalorieEstimator.cardioKcal(
      weightKg: weightKg,
      avgSpeedKmh: avgSpeedKmh,
      elapsedMs: elapsedMs,
      distanceMeters: distanceMeters,
    );
  }
}
