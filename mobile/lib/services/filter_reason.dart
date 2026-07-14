/// Motivo de aceitação/rejeição de um ponto GPS (Fase 2).
enum FilterReason {
  none,
  lowAccuracy,
  gpsJump,
  impossibleSpeed,
  duplicate,
  lowConfidence,
  /// Zig-zag / deriva típica de GPS no bolso (sensor fusion + bússola).
  stationaryJitter,
}

extension FilterReasonApi on FilterReason {
  String get apiName {
    switch (this) {
      case FilterReason.none:
        return 'NONE';
      case FilterReason.lowAccuracy:
        return 'LOW_ACCURACY';
      case FilterReason.gpsJump:
        return 'GPS_JUMP';
      case FilterReason.impossibleSpeed:
        return 'IMPOSSIBLE_SPEED';
      case FilterReason.duplicate:
        return 'DUPLICATE';
      case FilterReason.lowConfidence:
        return 'LOW_CONFIDENCE';
      case FilterReason.stationaryJitter:
        return 'STATIONARY_JITTER';
    }
  }

  static FilterReason fromApi(String? raw) {
    switch (raw) {
      case 'LOW_ACCURACY':
        return FilterReason.lowAccuracy;
      case 'GPS_JUMP':
        return FilterReason.gpsJump;
      case 'IMPOSSIBLE_SPEED':
        return FilterReason.impossibleSpeed;
      case 'DUPLICATE':
        return FilterReason.duplicate;
      case 'LOW_CONFIDENCE':
        return FilterReason.lowConfidence;
      case 'STATIONARY_JITTER':
        return FilterReason.stationaryJitter;
      default:
        return FilterReason.none;
    }
  }
}
