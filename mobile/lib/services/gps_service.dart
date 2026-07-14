import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Stream GPS oficial (geolocator → Fused Location / Core Location) + FGS Android.
class GpsService {
  GpsService._();
  static final instance = GpsService._();

  StreamSubscription<Position>? _subscription;

  bool get isStreaming => _subscription != null;

  LocationSettings buildSettings({
    required String notificationTitle,
    required String notificationText,
    /// Tela apagada / bolso: menos fixes, só com deslocamento real.
    /// Evita o espaguete típico de GPS ruidoso a cada 0,5 s.
    bool backgroundMode = false,
  }) {
    // Preferir `best` a `bestForNavigation`: navegação mistura bússola/giroscópio
    // e, com o celular no bolso, gera deriva em espaguete e km/ritmo errados.
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        // Em background o chip “salta” dentro do raio de erro; distanceFilter
        // nativo evita desenhar ida-e-volta na mesma calçada.
        distanceFilter: backgroundMode ? 8 : 0,
        intervalDuration: backgroundMode
            ? const Duration(milliseconds: 1500)
            : const Duration(milliseconds: 500),
        forceLocationManager: false,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: notificationTitle,
          notificationText: notificationText,
          notificationChannelName: 'Treino outdoor',
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon:
              const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: backgroundMode ? 8 : 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: backgroundMode ? 8 : 0,
    );
  }

  Future<Position?> getCurrentFix({
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: false,
        timeLimit: timeLimit,
      );
    } catch (_) {
      return null;
    }
  }

  StreamSubscription<Position> listen({
    required LocationSettings settings,
    required void Function(Position pos) onPosition,
    void Function(Object error)? onError,
  }) {
    _subscription?.cancel();
    _subscription = Geolocator.getPositionStream(locationSettings: settings)
        .listen(onPosition, onError: onError);
    return _subscription!;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();
}
