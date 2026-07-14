import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:foco_academia_mobile/services/lap_detector_service.dart';

/// Quadrado ~250 m de lado (volta ~1 km) ao redor de um ponto.
List<LatLng> _squareLoop({
  required LatLng start,
  required int stepsPerSide,
  double sideMeters = 250,
}) {
  // ~111320 m por grau de latitude.
  final dLat = (sideMeters / 111320.0) / stepsPerSide;
  final dLng =
      (sideMeters / (111320.0 * 0.92)) / stepsPerSide; // approx cos(-23°)

  final out = <LatLng>[start];
  var lat = start.latitude;
  var lng = start.longitude;

  // Norte
  for (var i = 0; i < stepsPerSide; i++) {
    lat -= dLat;
    out.add(LatLng(lat, lng));
  }
  // Leste
  for (var i = 0; i < stepsPerSide; i++) {
    lng += dLng;
    out.add(LatLng(lat, lng));
  }
  // Sul
  for (var i = 0; i < stepsPerSide; i++) {
    lat += dLat;
    out.add(LatLng(lat, lng));
  }
  // Oeste — volta perto do início
  for (var i = 0; i < stepsPerSide; i++) {
    lng -= dLng;
    out.add(LatLng(lat, lng));
  }
  // Fecha no ponto de partida.
  out.add(start);
  return out;
}

void main() {
  test('detecta voltas ao fechar o loop no ponto de partida', () {
    final detector = LapDetectorService(
      closeRadiusMeters: 35,
      leaveRadiusMeters: 50,
      minLapMeters: 200,
      minPointsPerLap: 6,
    );
    const start = LatLng(-23.55000, -46.63000);
    final loop = _squareLoop(start: start, stepsPerSide: 8);

    // Duas voltas completas.
    for (final p in [...loop, ...loop.skip(1)]) {
      detector.addPoint(p);
    }

    expect(detector.completedLaps.length, greaterThanOrEqualTo(1));
    expect(detector.lapCount, greaterThanOrEqualTo(2));
    expect(detector.completedLaps.first.lapNumber, 1);
    expect(detector.completedLaps.first.distanceMeters, greaterThan(200));
  });

  test('não conta volta sem sair e voltar ao início', () {
    final detector = LapDetectorService(minLapMeters: 180);
    const start = LatLng(-23.55000, -46.63000);
    // Só caminha para o norte ~200 m e fica longe do início.
    for (var i = 0; i <= 20; i++) {
      detector.addPoint(LatLng(-23.55000 - i * 0.00009, -46.63000));
    }
    expect(detector.completedLaps, isEmpty);
    expect(detector.lapCount, 1); // só a volta ativa
    expect(detector.activeLap, isNotNull);
  });

  test('cores cíclicas por número da volta', () {
    expect(
      LapDetectorService.colorForLap(1),
      LapDetectorService.lapColors[0],
    );
    expect(
      LapDetectorService.colorForLap(2),
      LapDetectorService.lapColors[1],
    );
    expect(
      LapDetectorService.colorForLap(9),
      LapDetectorService.lapColors[0],
    );
  });

  test('rebuildFrom reconstrói as mesmas voltas', () {
    final detector = LapDetectorService(
      closeRadiusMeters: 35,
      leaveRadiusMeters: 50,
      minLapMeters: 200,
      minPointsPerLap: 6,
    );
    const start = LatLng(-23.55000, -46.63000);
    final loop = _squareLoop(start: start, stepsPerSide: 8);
    final trail = [...loop, ...loop.skip(1)];
    final laps = detector.rebuildFrom(trail);
    expect(laps.length, greaterThanOrEqualTo(2));
  });
}
