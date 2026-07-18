import 'calorie_estimator.dart';
import 'profile_service.dart';
import 'weight_service.dart';

/// Peso e altura do atleta para cálculos de calorias.
class AthleteMetrics {
  const AthleteMetrics({
    required this.weightKg,
    this.heightCm,
    required this.usingDefaultWeight,
    required this.weightSource,
  });

  final double weightKg;
  final double? heightCm;
  final bool usingDefaultWeight;

  /// `profile`, `measurement` ou `default`.
  final String weightSource;
}

/// Estimativa de calorias (MET) — fachada Fase 1.
class CaloriesService {
  CaloriesService._();
  static final instance = CaloriesService._();

  double resolveWeight(double? kg) => CalorieEstimator.resolveWeight(kg);

  /// Peso e altura: perfil → última pesagem → padrão 70 kg.
  Future<AthleteMetrics> loadAthleteMetrics() async {
    double? heightCm;
    double? fromProfile;
    try {
      final profile = await ProfileService.instance.getProfile();
      fromProfile = profile.currentWeightKg;
      heightCm = profile.heightCm;
    } catch (_) {}

    if (fromProfile != null && fromProfile >= 20 && fromProfile <= 500) {
      return AthleteMetrics(
        weightKg: fromProfile,
        heightCm: heightCm,
        usingDefaultWeight: false,
        weightSource: 'profile',
      );
    }

    try {
      final list = await WeightService.instance.list();
      if (list.isNotEmpty) {
        final latest = list.first.weightKg;
        if (latest >= 20 && latest <= 500) {
          return AthleteMetrics(
            weightKg: latest,
            heightCm: heightCm,
            usingDefaultWeight: false,
            weightSource: 'measurement',
          );
        }
      }
    } catch (_) {}

    return AthleteMetrics(
      weightKg: CalorieEstimator.defaultWeightKg,
      heightCm: heightCm,
      usingDefaultWeight: true,
      weightSource: 'default',
    );
  }

  /// Peso para kcal: perfil → última pesagem → padrão 70 kg.
  Future<double> loadAthleteWeightKg() async {
    final metrics = await loadAthleteMetrics();
    return metrics.weightKg;
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
