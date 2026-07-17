import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/calorie_estimator.dart';

void main() {
  test('0,6 km em 14 min com 70 kg fica ~40 kcal (não 105)', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 2.6, // 0,6 km / 14 min
      elapsedMs: 14 * 60 * 1000,
      distanceMeters: 600,
    );
    expect(kcal, greaterThanOrEqualTo(25));
    expect(kcal, lessThanOrEqualTo(55));
  });

  test('teto por km evita explosão com MET alto falso', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 12, // MET de corrida falso
      elapsedMs: 14 * 60 * 1000,
      distanceMeters: 600,
    );
    expect(kcal, lessThan(70));
  });

  test('corrida 5 km em 30 min permanece na faixa esperada', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 10,
      elapsedMs: 30 * 60 * 1000,
      distanceMeters: 5000,
    );
    expect(kcal, greaterThan(250));
    expect(kcal, lessThan(450));
  });

  test('caminhada 5 km com 80 kg fica ~250–350 kcal (não subestima absurdo)', () {
    // ~5 km/h → 1 h; MET caminhada × 80 kg ≈ 280–320 kcal.
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 80,
      avgSpeedKmh: 5,
      elapsedMs: 60 * 60 * 1000,
      distanceMeters: 5000,
    );
    expect(kcal, greaterThanOrEqualTo(240));
    expect(kcal, lessThanOrEqualTo(360));
  });

  test('5,2 km a 5 km/h com 80 kg ≈ 310–330 kcal (não 279 do peso padrão 70)', () {
    // 5 km/h é ritmo normal de caminhada — não é “muito lento”.
    final with80 = CalorieEstimator.cardioKcal(
      weightKg: 80,
      avgSpeedKmh: 5,
      elapsedMs: (5.2 / 5.0 * 3600 * 1000).round(),
      distanceMeters: 5200,
    );
    final with70 = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 5,
      elapsedMs: (5.2 / 5.0 * 3600 * 1000).round(),
      distanceMeters: 5200,
    );
    expect(with80, greaterThanOrEqualTo(300));
    expect(with80, lessThanOrEqualTo(340));
    expect(with70, greaterThanOrEqualTo(260));
    expect(with70, lessThanOrEqualTo(290));
    // Os 279 relatados batem com ~70 kg, não com 80 kg.
    expect(with70, closeTo(279, 5));
  });

  test('parado sem distância → 0 kcal (não inventa gasto)', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 0,
      elapsedMs: 5 * 60 * 1000,
      distanceMeters: 0,
    );
    expect(kcal, 0);
  });

  test('parado sem distanceMeters → 0 kcal', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 0,
      elapsedMs: 10 * 60 * 1000,
    );
    expect(kcal, 0);
  });

  test('drift GPS minúsculo parado não gera dezenas de kcal', () {
    final kcal = CalorieEstimator.cardioKcal(
      weightKg: 70,
      avgSpeedKmh: 0.2,
      elapsedMs: 5 * 60 * 1000,
      distanceMeters: 12,
    );
    expect(kcal, 0);
  });
}
