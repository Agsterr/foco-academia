/// Filtro de Kalman 2D leve para suavizar lat/lng (Fase 2).
///
/// Não inventa trajetos: só amortece ruído. Distância oficial continua
/// nos pontos filtrados; o Kalman melhora estabilidade do desenho/posição.
class KalmanFilterService {
  KalmanFilterService({
    this.processNoise = 3e-6,
    this.enabled = true,
  });

  final double processNoise;
  bool enabled;

  double? _lat;
  double? _lng;
  double _pLat = 1;
  double _pLng = 1;

  void reset() {
    _lat = null;
    _lng = null;
    _pLat = 1;
    _pLng = 1;
  }

  /// Retorna posição suavizada. [accuracyMeters] vira ruído de medição.
  ({double lat, double lng}) smooth({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) {
    if (!enabled) {
      return (lat: latitude, lng: longitude);
    }

    final r = _measurementNoise(accuracyMeters);

    if (_lat == null || _lng == null) {
      _lat = latitude;
      _lng = longitude;
      _pLat = r;
      _pLng = r;
      return (lat: latitude, lng: longitude);
    }

    // Predição (modelo estático + pouco ruído de processo).
    _pLat += processNoise;
    _pLng += processNoise;

    // Update latitude
    final kLat = _pLat / (_pLat + r);
    _lat = _lat! + kLat * (latitude - _lat!);
    _pLat = (1 - kLat) * _pLat;

    // Update longitude
    final kLng = _pLng / (_pLng + r);
    _lng = _lng! + kLng * (longitude - _lng!);
    _pLng = (1 - kLng) * _pLng;

    return (lat: _lat!, lng: _lng!);
  }

  double _measurementNoise(double accuracyMeters) {
    final a = accuracyMeters.isNaN || accuracyMeters <= 0 ? 15.0 : accuracyMeters;
    // Converte metros ~ graus (aprox. equatorial) e eleva para variância.
    final deg = a / 111320.0;
    return (deg * deg).clamp(1e-12, 1e-4);
  }
}
