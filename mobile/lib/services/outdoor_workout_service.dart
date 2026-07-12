import 'active_run_store.dart';
import 'calories_service.dart';
import 'distance_calculator_service.dart';
import 'gps_tracking_engine.dart';

/// Orquestra métricas da sessão outdoor (pipeline GPS).
class OutdoorWorkoutService {
  OutdoorWorkoutService._();
  static final instance = OutdoorWorkoutService._();

  String formatNotificationText({
    required bool paused,
    required bool manualPaused,
    required double distanceMeters,
    required double? paceSecPerKm,
    required double speedKmh,
    required int calories,
    required int elapsedSec,
  }) {
    final km = (distanceMeters / 1000).toStringAsFixed(2);
    final pace = GpsTrackingEngine.formatPace(paceSecPerKm);
    final speed = speedKmh.toStringAsFixed(1);
    final time = _fmt(elapsedSec);
    if (paused) {
      final label = manualPaused ? 'Pausado' : 'Auto-pause';
      return '$label · $km km · $time · $calories kcal';
    }
    return '$time · $km km · $pace · $speed km/h · $calories kcal';
  }

  int liveCalories({
    required double weightKg,
    required double avgSpeedKmh,
    required int elapsedSec,
    required double distanceMeters,
  }) {
    return CaloriesService.instance.cardioKcal(
      weightKg: weightKg,
      avgSpeedKmh: avgSpeedKmh,
      elapsedMs: elapsedSec * 1000,
      distanceMeters: distanceMeters,
    );
  }

  double averageSpeedKmh({
    required double distanceMeters,
    required int movingElapsedSec,
  }) {
    return DistanceCalculatorService.instance.averageSpeedKmh(
      distanceMeters: distanceMeters,
      movingElapsedSec: movingElapsedSec,
    );
  }

  Future<ActiveRunSnapshot?> loadActiveRun() => ActiveRunStore.instance.load();

  Future<void> clearActiveRun() => ActiveRunStore.instance.clear();

  Future<bool> hasActiveRun() => ActiveRunStore.instance.hasActiveFlag();

  static String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
}
