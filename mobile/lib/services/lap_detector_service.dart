import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Uma volta fechada (ex.: campo / pista) com seus pontos.
class RouteLap {
  const RouteLap({
    required this.lapNumber,
    required this.points,
    required this.distanceMeters,
  });

  /// 1 = primeira volta, 2 = segunda, …
  final int lapNumber;
  final List<LatLng> points;
  final double distanceMeters;
}

/// Detecta voltas quando o atleta retorna perto do ponto de partida
/// depois de percorrer uma distância mínima (corrida em campo/quadra).
class LapDetectorService {
  LapDetectorService({
    this.closeRadiusMeters = 28,
    this.leaveRadiusMeters = 45,
    this.minLapMeters = 180,
    this.minPointsPerLap = 8,
  });

  /// Raio para “fechou a volta” perto do início.
  final double closeRadiusMeters;

  /// Precisa sair deste raio antes de contar a próxima volta.
  final double leaveRadiusMeters;

  /// Distância mínima desde o início da volta atual.
  final double minLapMeters;

  final int minPointsPerLap;

  LatLng? _anchor;
  bool _leftStartZone = false;
  double _distanceThisLap = 0;
  LatLng? _lastPoint;
  final List<LatLng> _current = [];
  final List<RouteLap> _completed = [];

  List<RouteLap> get completedLaps => List.unmodifiable(_completed);

  /// Volta em andamento (ainda não fechada).
  RouteLap? get activeLap {
    if (_current.length < 2) return null;
    return RouteLap(
      lapNumber: _completed.length + 1,
      points: List.unmodifiable(_current),
      distanceMeters: _distanceThisLap,
    );
  }

  int get lapCount => _completed.length + (activeLap != null ? 1 : 0);

  /// Todas as voltas para desenhar (fechadas + atual).
  List<RouteLap> get allLaps {
    final out = <RouteLap>[..._completed];
    final active = activeLap;
    if (active != null) out.add(active);
    return out;
  }

  void reset() {
    _anchor = null;
    _leftStartZone = false;
    _distanceThisLap = 0;
    _lastPoint = null;
    _current.clear();
    _completed.clear();
  }

  /// Reconstrói voltas a partir de uma trilha já gravada.
  List<RouteLap> rebuildFrom(List<LatLng> points) {
    reset();
    for (final p in points) {
      addPoint(p);
    }
    return allLaps;
  }

  void addPoint(LatLng point) {
    if (_anchor == null) {
      _anchor = point;
      _current.add(point);
      _lastPoint = point;
      return;
    }

    if (_lastPoint != null) {
      final step = Geolocator.distanceBetween(
        _lastPoint!.latitude,
        _lastPoint!.longitude,
        point.latitude,
        point.longitude,
      );
      if (step >= 0.5) {
        _distanceThisLap += step;
      }
    }
    _lastPoint = point;
    _current.add(point);

    final toStart = Geolocator.distanceBetween(
      _anchor!.latitude,
      _anchor!.longitude,
      point.latitude,
      point.longitude,
    );

    if (!_leftStartZone) {
      if (toStart >= leaveRadiusMeters) {
        _leftStartZone = true;
      }
      return;
    }

    final canClose = _leftStartZone &&
        toStart <= closeRadiusMeters &&
        _distanceThisLap >= minLapMeters &&
        _current.length >= minPointsPerLap;

    if (!canClose) return;

    // Fecha a volta e inicia a próxima a partir deste ponto.
    _completed.add(
      RouteLap(
        lapNumber: _completed.length + 1,
        points: List.unmodifiable(_current),
        distanceMeters: _distanceThisLap,
      ),
    );
    _current
      ..clear()
      ..add(point);
    _distanceThisLap = 0;
    _leftStartZone = false;
  }

  /// Paleta distinta por volta (cíclica).
  static const lapColors = <int>[
    0xFFFC4C02, // laranja Strava — volta 1
    0xFF0D9488, // teal
    0xFF2563EB, // azul
    0xFFD97706, // âmbar
    0xFFE11D48, // rosa
    0xFF16A34A, // verde
    0xFF0891B2, // ciano
    0xFFCA8A04, // amarelo queimado
  ];

  static int colorForLap(int lapNumber) {
    if (lapNumber < 1) return lapColors.first;
    return lapColors[(lapNumber - 1) % lapColors.length];
  }
}
