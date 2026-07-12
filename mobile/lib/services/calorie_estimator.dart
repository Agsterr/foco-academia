/// Estimativa de calorias via MET (Metabolic Equivalent of Task).
/// kcal = MET × peso(kg) × tempo(horas)
///
/// Com teto por km para não explodir quando GPS/tempo/velocidade falham
/// (ex.: 0,6 km em 14 min não pode dar 105 kcal).
class CalorieEstimator {
  static const double defaultWeightKg = 70.0;

  static const List<(double speed, double met)> _walk = [
    (2.0, 2.0),
    (3.0, 2.5),
    (4.0, 3.0),
    (5.0, 3.8),
    (6.0, 4.8),
  ];

  static const List<(double speed, double met)> _run = [
    (7.0, 7.0),
    (8.0, 8.3),
    (9.0, 9.0),
    (10.0, 9.8),
    (11.0, 10.5),
    (12.0, 11.8),
    (13.0, 12.8),
  ];

  static const Map<String, double> intensityMet = {
    'LEVE': 3.5,
    'MODERADA': 5.0,
    'PESADA': 6.5,
    'MUITO_INTENSA': 8.0,
  };

  static double resolveWeight(double? kg) {
    if (kg == null || kg < 20 || kg > 500) return defaultWeightKg;
    return kg;
  }

  static double metForSpeedKmh(double speedKmh) {
    if (speedKmh <= 0) return 2.0;
    if (speedKmh < 6.5) return _interpolate(_walk, speedKmh);
    return _interpolate(_run, speedKmh);
  }

  /// [distanceMeters] opcional: recalcula velocidade e aplica teto por km.
  static int cardioKcal({
    required double weightKg,
    required double avgSpeedKmh,
    required int elapsedMs,
    double? distanceMeters,
  }) {
    if (elapsedMs <= 0) return 0;
    final w = resolveWeight(weightKg);
    final hours = elapsedMs / 3600000.0;
    if (hours <= 0) return 0;

    // Velocidade efetiva: prioriza distância/tempo (mais estável que média ruidosa).
    var speed = avgSpeedKmh.isFinite ? avgSpeedKmh : 0.0;
    if (distanceMeters != null && distanceMeters >= 20 && hours > 0) {
      final fromDist = (distanceMeters / 1000.0) / hours;
      if (fromDist.isFinite && fromDist > 0) {
        speed = fromDist;
      }
    }
    speed = speed.clamp(0.0, 22.0);

    final met = metForSpeedKmh(speed);
    var kcal = met * w * hours;

    // Teto por km (ACSMs / regras práticas):
    // caminhada ~0,6–0,9 kcal/kg/km; corrida ~1,0–1,2 kcal/kg/km.
    if (distanceMeters != null && distanceMeters > 0) {
      final km = distanceMeters / 1000.0;
      final perKgPerKm = speed >= 6.5 ? 1.15 : 0.85;
      final cap = perKgPerKm * w * km * 1.2; // 20% folga
      final floor = 1.3 * w * hours; // quase parado / muito lento
      if (cap > floor) {
        kcal = kcal.clamp(floor, cap);
      }
    }

    return kcal.round().clamp(0, 100000);
  }

  static int strengthKcal({
    required double weightKg,
    required int durationSeconds,
    required String intensity,
  }) {
    if (durationSeconds <= 0) return 0;
    final met = intensityMet[intensity] ?? 5.0;
    final hours = durationSeconds / 3600.0;
    return (met * resolveWeight(weightKg) * hours).round().clamp(0, 100000);
  }

  static double _interpolate(List<(double speed, double met)> table, double speed) {
    if (speed <= table.first.$1) return table.first.$2;
    for (var i = 1; i < table.length; i++) {
      if (speed <= table[i].$1) {
        final s0 = table[i - 1].$1;
        final m0 = table[i - 1].$2;
        final s1 = table[i].$1;
        final m1 = table[i].$2;
        final t = (speed - s0) / (s1 - s0);
        return m0 + t * (m1 - m0);
      }
    }
    return table.last.$2;
  }
}
