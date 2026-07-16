/// Estimativa de calorias via MET (Metabolic Equivalent of Task).
/// kcal = MET × peso(kg) × tempo(horas)
///
/// Regras práticas (estilo apps de corrida):
/// - Sem deslocamento real → **0 kcal** (não inventa gasto parado com o treino aberto).
/// - Teto por km para não explodir quando GPS/tempo/velocidade falham
///   (ex.: 0,6 km em 14 min não pode dar 105 kcal).
/// - Piso por **km** (não por tempo), para não empurrar kcal enquanto o relógio anda parado.
class CalorieEstimator {
  static const double defaultWeightKg = 70.0;

  /// Abaixo disso (km/h) + sem distância → considerado parado.
  static const double stationarySpeedKmh = 1.0;

  /// Distância mínima para contar calorias só pelo tempo/MET.
  static const double minDistanceMeters = 20.0;

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
    if (speedKmh <= 0.3) return 1.0; // em pé / parado — sem gasto de exercício
    if (speedKmh < 2.0) {
      // Sobe de 1.0 → 2.0 entre 0,3 e 2 km/h (evita salto MET 2.0 parado).
      final t = ((speedKmh - 0.3) / (2.0 - 0.3)).clamp(0.0, 1.0);
      return 1.0 + t * 1.0;
    }
    if (speedKmh < 6.5) return _interpolate(_walk, speedKmh);
    return _interpolate(_run, speedKmh);
  }

  /// [distanceMeters] opcional: recalcula velocidade e aplica teto/piso por km.
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
    if (distanceMeters != null && distanceMeters >= minDistanceMeters && hours > 0) {
      final fromDist = (distanceMeters / 1000.0) / hours;
      if (fromDist.isFinite && fromDist > 0) {
        speed = fromDist;
      }
    }
    speed = speed.clamp(0.0, 22.0);

    final moved =
        distanceMeters != null && distanceMeters >= minDistanceMeters;

    // Parado com o treino aberto: não acumula kcal “fantasma”.
    if (!moved && speed < stationarySpeedKmh) return 0;

    // Quase parado com drift de GPS: só o que o km justifica (não o relógio).
    if (moved && speed < 0.6) {
      final km = distanceMeters! / 1000.0;
      return (0.7 * w * km).round().clamp(0, 100000);
    }

    final met = metForSpeedKmh(speed);
    var kcal = met * w * hours;

    // Teto/piso por km (ACSMs / regras práticas):
    // caminhada ~0,6–0,9 kcal/kg/km; corrida ~1,0–1,2 kcal/kg/km.
    // Piso por km — nunca por tempo — senão kcal sobe parado.
    if (distanceMeters != null && distanceMeters > 0) {
      final km = distanceMeters / 1000.0;
      final perKgPerKm = speed >= 6.5 ? 1.15 : 0.85;
      final cap = perKgPerKm * w * km * 1.2; // 20% folga
      final floor = 0.55 * w * km;
      if (cap >= floor) {
        kcal = kcal.clamp(floor, cap);
      } else {
        kcal = kcal.clamp(0.0, cap);
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
