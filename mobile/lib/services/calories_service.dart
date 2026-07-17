import 'calorie_estimator.dart';
import 'profile_service.dart';
import 'weight_service.dart';

/// Estimativa de calorias (MET) — fachada Fase 1.
class CaloriesService {
  CaloriesService._();
  static final instance = CaloriesService._();

  double resolveWeight(double? kg) => CalorieEstimator.resolveWeight(kg);

  /// Peso para kcal: perfil → última pesagem → padrão 70 kg.
  /// Os ~279 kcal em 5,2 km a 5 km/h batem com 70 kg (padrão), não com 80 kg.
  Future<double> loadAthleteWeightKg() async {
    double? fromProfile;
    try {
      final profile = await ProfileService.instance.getProfile();
      fromProfile = profile.currentWeightKg;
    } catch (_) {}

    if (fromProfile != null && fromProfile >= 20 && fromProfile <= 500) {
      return fromProfile;
    }

    try {
      final list = await WeightService.instance.list();
      if (list.isNotEmpty) {
        final latest = list.first.weightKg;
        if (latest >= 20 && latest <= 500) return latest;
      }
    } catch (_) {}

    return CalorieEstimator.defaultWeightKg;
  }

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
