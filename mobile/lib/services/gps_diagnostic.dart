enum GpsDiagnosticEvent {
  gpsLost,
  gpsRecovered,
  batteryOptimization,
  permissionDenied,
  backgroundRestricted,
  lowBattery,
  locationProviderChanged,
  mockLocationDetected,
  /// App foi para background / tela apagada durante o treino.
  screenOffMode,
  /// Accuracy ruim persistente (típico de bolso / canyon).
  poorAccuracy,
  /// Keepalive pontual usado porque o stream silenciou.
  keepaliveFix,
  /// Modo Economia de energia / Battery Saver do sistema ligado.
  powerSaverMode,
}

extension GpsDiagnosticEventApi on GpsDiagnosticEvent {
  String get apiName {
    switch (this) {
      case GpsDiagnosticEvent.gpsLost:
        return 'GPS_LOST';
      case GpsDiagnosticEvent.gpsRecovered:
        return 'GPS_RECOVERED';
      case GpsDiagnosticEvent.batteryOptimization:
        return 'BATTERY_OPTIMIZATION';
      case GpsDiagnosticEvent.permissionDenied:
        return 'PERMISSION_DENIED';
      case GpsDiagnosticEvent.backgroundRestricted:
        return 'BACKGROUND_RESTRICTED';
      case GpsDiagnosticEvent.lowBattery:
        return 'LOW_BATTERY';
      case GpsDiagnosticEvent.locationProviderChanged:
        return 'LOCATION_PROVIDER_CHANGED';
      case GpsDiagnosticEvent.mockLocationDetected:
        return 'MOCK_LOCATION_DETECTED';
      case GpsDiagnosticEvent.screenOffMode:
        return 'SCREEN_OFF_MODE';
      case GpsDiagnosticEvent.poorAccuracy:
        return 'POOR_ACCURACY';
      case GpsDiagnosticEvent.keepaliveFix:
        return 'KEEPALIVE_FIX';
      case GpsDiagnosticEvent.powerSaverMode:
        return 'POWER_SAVER_MODE';
    }
  }
}

class GpsDiagnosticEventRecord {
  const GpsDiagnosticEventRecord({
    required this.eventType,
    required this.timestamp,
    this.message,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.clientSessionId,
  });

  final GpsDiagnosticEvent eventType;
  final DateTime timestamp;
  final String? message;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? clientSessionId;

  Map<String, dynamic> toJson() => {
        'eventType': eventType.apiName,
        'timestamp': timestamp.toUtc().toIso8601String(),
        if (message != null) 'message': message,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (clientSessionId != null) 'clientSessionId': clientSessionId,
      };
}
