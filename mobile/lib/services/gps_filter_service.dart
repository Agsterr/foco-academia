import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'filter_reason.dart';
import 'gps_tracking_engine.dart';

class GpsFilterDecision {
  const GpsFilterDecision.accept({
    required this.confidenceScore,
  })  : reason = FilterReason.none,
        accepted = true;

  const GpsFilterDecision.reject(
    this.reason, {
    required this.confidenceScore,
  }) : accepted = false;

  final bool accepted;
  final FilterReason reason;
  final double confidenceScore;
}

/// Filtros de qualidade GPS + confidence score (0–1).
class GpsFilterService {
  GpsFilterService({
    this.maxAccuracyMeters = 45,
    this.relaxedAccuracyMeters = 70,
    this.maxSpeedKmh = 40,
    this.maxJumpMeters = 90,
    this.minDistanceMeters = 2.5,
    this.minConfidence = 0.25,
    this.confidenceEnabled = true,
    this.jumpDetectionEnabled = true,
    this.jitterDetectionEnabled = true,
    this.backgroundMode = false,
  });

  double maxAccuracyMeters;
  double relaxedAccuracyMeters;
  double maxSpeedKmh;
  double maxJumpMeters;
  double minDistanceMeters;
  double minConfidence;
  bool confidenceEnabled;
  bool jumpDetectionEnabled;
  bool jitterDetectionEnabled;
  /// Tela apagada / bolso: exige passo maior que o ruído do chip.
  bool backgroundMode;

  /// Accuracy 3 m → ~0.99; 8 m → ~0.95; 20 m → ~0.75; 45 m → ~0.35
  double confidenceFromAccuracy(double accuracyMeters) {
    if (accuracyMeters.isNaN || accuracyMeters <= 0) return 0.9;
    final score = 1.0 / (1.0 + math.pow(accuracyMeters / 35.0, 2.0));
    return score.clamp(0.0, 1.0);
  }

  double accuracyLimit({
    required bool relaxed,
  }) {
    if (backgroundMode) {
      // Tela apagada: não desenha no mapa com accuracy de canyon urbano.
      return relaxed ? 48.0 : 32.0;
    }
    return relaxed ? relaxedAccuracyMeters : maxAccuracyMeters;
  }

  /// Bearing inicial→final em graus [0, 360).
  static double bearingDegrees({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    final phi1 = lat1 * math.pi / 180.0;
    final phi2 = lat2 * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    final theta = math.atan2(y, x) * 180.0 / math.pi;
    return (theta + 360.0) % 360.0;
  }

  /// Ângulo absoluto entre dois bearings (0–180°).
  static double bearingDeltaDegrees(double b1, double b2) {
    var d = (b2 - b1).abs() % 360.0;
    if (d > 180) d = 360 - d;
    return d;
  }

  GpsFilterDecision evaluate({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime recordedAt,
    TrackedPoint? previous,
    TrackedPoint? beforePrevious,
    bool relaxedAccuracy = false,
  }) {
    final confidence = confidenceFromAccuracy(accuracyMeters);
    final limit = accuracyLimit(relaxed: relaxedAccuracy);

    if (accuracyMeters > limit) {
      return GpsFilterDecision.reject(
        FilterReason.lowAccuracy,
        confidenceScore: confidence,
      );
    }

    if (confidenceEnabled && confidence < minConfidence) {
      return GpsFilterDecision.reject(
        FilterReason.lowConfidence,
        confidenceScore: confidence,
      );
    }

    if (previous != null && jumpDetectionEnabled) {
      final jumpDelta = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        latitude,
        longitude,
      );
      final jumpDt =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;

      // Tela apagada: saltos curtos dentro do raio de erro viram espaguete no mapa.
      final jumpCap = backgroundMode
          ? math.min(maxJumpMeters, math.max(35.0, accuracyMeters * 1.6))
          : maxJumpMeters;
      if (jumpDt < 12 && jumpDelta > jumpCap) {
        return GpsFilterDecision.reject(
          FilterReason.gpsJump,
          confidenceScore: confidence,
        );
      }

      if (jumpDt > 0.4 && jumpDt < 12) {
        final implied = (jumpDelta / jumpDt) * 3.6;
        if (implied > maxSpeedKmh) {
          return GpsFilterDecision.reject(
            FilterReason.impossibleSpeed,
            confidenceScore: confidence,
          );
        }
      }

      // Min distance sobe com accuracy ruim (bolso / canyon urbano).
      // Em background o passo precisa superar o ruído típico do chip (~accuracy).
      final dynMin = backgroundMode
          ? math.max(
              math.max(minDistanceMeters, 8.0),
              math.min(accuracyMeters * 0.55, 18.0),
            )
          : math.max(
              minDistanceMeters,
              math.min(accuracyMeters * 0.22, 6.0),
            );
      if (jumpDt < 20 && jumpDelta < dynMin) {
        return GpsFilterDecision.reject(
          FilterReason.duplicate,
          confidenceScore: confidence,
        );
      }

      // Zig-zag típico de deriva GPS no bolso: volta atrás dentro do raio de erro.
      if (jitterDetectionEnabled &&
          beforePrevious != null &&
          jumpDt > 0.2 &&
          jumpDt < 18) {
        final prevSeg = Geolocator.distanceBetween(
          beforePrevious.latitude,
          beforePrevious.longitude,
          previous.latitude,
          previous.longitude,
        );
        final noiseScale = backgroundMode ? 1.15 : 0.95;
        final noiseRadius = math.max(
          backgroundMode ? 14.0 : 10.0,
          math.max(
            accuracyMeters,
            previous.accuracyMeters ?? accuracyMeters,
          ) * noiseScale,
        );
        if (prevSeg > 0.5 &&
            jumpDelta > 0.5 &&
            prevSeg < noiseRadius &&
            jumpDelta < noiseRadius) {
          final b1 = bearingDegrees(
            lat1: beforePrevious.latitude,
            lng1: beforePrevious.longitude,
            lat2: previous.latitude,
            lng2: previous.longitude,
          );
          final b2 = bearingDegrees(
            lat1: previous.latitude,
            lng1: previous.longitude,
            lat2: latitude,
            lng2: longitude,
          );
          final turn = bearingDeltaDegrees(b1, b2);
          final backToBefore = Geolocator.distanceBetween(
            beforePrevious.latitude,
            beforePrevious.longitude,
            latitude,
            longitude,
          );
          // Ida/volta na calçada: curva fechada OU quase retorna ao ponto anterior.
          final turnLimit = backgroundMode ? 75.0 : 95.0;
          final backLimit = backgroundMode ? 0.85 : 0.7;
          if (turn >= turnLimit || backToBefore < noiseRadius * backLimit) {
            return GpsFilterDecision.reject(
              FilterReason.stationaryJitter,
              confidenceScore: confidence,
            );
          }
        }
      }
    }

    return GpsFilterDecision.accept(confidenceScore: confidence);
  }

  /// Limite de velocidade por tipo de atividade.
  static double maxSpeedForActivity(MotionActivity activity) {
    switch (activity) {
      case MotionActivity.walk:
        // 12 km/h: passo nativo de 8 m a cada ~2,5 s (tela apagada) não estoura.
        return 12;
      case MotionActivity.run:
        return 30;
      case MotionActivity.stopped:
        return 8;
    }
  }
}
