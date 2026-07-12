import 'package:geolocator/geolocator.dart';

/// Distância haversine entre pontos (WGS84 via geolocator).
class DistanceCalculatorService {
  DistanceCalculatorService._();
  static final instance = DistanceCalculatorService._();

  double betweenMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Soma a distância entre pares consecutivos de pontos.
  double pathMeters(
    List<({double lat, double lng})> points,
  ) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += betweenMeters(
        lat1: points[i - 1].lat,
        lng1: points[i - 1].lng,
        lat2: points[i].lat,
        lng2: points[i].lng,
      );
    }
    return total;
  }

  /// Pace médio em segundos por km (null se inválido).
  double? averagePaceSecPerKm({
    required double distanceMeters,
    required int movingElapsedSec,
  }) {
    if (distanceMeters < 10 || movingElapsedSec <= 0) return null;
    final km = distanceMeters / 1000.0;
    if (km <= 0) return null;
    return movingElapsedSec / km;
  }

  double averageSpeedKmh({
    required double distanceMeters,
    required int movingElapsedSec,
  }) {
    if (movingElapsedSec <= 0 || distanceMeters <= 0) return 0;
    return (distanceMeters / 1000.0) / (movingElapsedSec / 3600.0);
  }
}
