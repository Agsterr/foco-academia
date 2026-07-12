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
  });

  double maxAccuracyMeters;
  double relaxedAccuracyMeters;
  double maxSpeedKmh;
  double maxJumpMeters;
  double minDistanceMeters;
  double minConfidence;
  bool confidenceEnabled;
  bool jumpDetectionEnabled;

  /// Accuracy 3 m → ~0.99; 8 m → ~0.95; 20 m → ~0.75; 45 m → ~0.35
  double confidenceFromAccuracy(double accuracyMeters) {
    if (accuracyMeters.isNaN || accuracyMeters <= 0) return 0.9;
    final score = 1.0 / (1.0 + math.pow(accuracyMeters / 35.0, 2.0));
    return score.clamp(0.0, 1.0);
  }

  double accuracyLimit({
    required bool relaxed,
  }) =>
      relaxed ? relaxedAccuracyMeters : maxAccuracyMeters;

  GpsFilterDecision evaluate({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime recordedAt,
    TrackedPoint? previous,
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

      if (jumpDt < 12 && jumpDelta > maxJumpMeters) {
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

      if (jumpDt < 20 && jumpDelta < minDistanceMeters) {
        return GpsFilterDecision.reject(
          FilterReason.duplicate,
          confidenceScore: confidence,
        );
      }
    }

    return GpsFilterDecision.accept(confidenceScore: confidence);
  }

  /// Limite de velocidade por tipo de atividade.
  static double maxSpeedForActivity(MotionActivity activity) {
    switch (activity) {
      case MotionActivity.walk:
        return 10;
      case MotionActivity.run:
        return 30;
      case MotionActivity.stopped:
        return 6;
    }
  }
}
