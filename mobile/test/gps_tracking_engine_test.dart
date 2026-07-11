import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:foco_academia_mobile/services/gps_tracking_engine.dart';
import 'package:foco_academia_mobile/services/run_export_service.dart';

Position _pos({
  required double lat,
  required double lng,
  double accuracy = 10,
  double speed = 2,
  double altitude = 100,
  DateTime? timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: altitude,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

void main() {
  test('rejeita precisão ruim e não move lastAccepted', () {
    final engine = GpsTrackingEngine();
    final ok = engine.process(
      _pos(lat: -23.55, lng: -46.63),
      now: DateTime(2026, 1, 1, 12, 0, 0),
    );
    expect(ok.accepted, isTrue);

    final bad = engine.process(
      _pos(lat: -23.5501, lng: -46.6301, accuracy: 50),
      now: DateTime(2026, 1, 1, 12, 0, 5),
    );
    expect(bad.accepted, isFalse);
    expect(bad.rejectReason, GpsRejectReason.accuracy);
    expect(engine.acceptedPoints.length, 1);
  });

  test('rejeita salto absurdo sem adicionar ao mapa', () {
    final engine = GpsTrackingEngine();
    engine.process(
      _pos(lat: -23.55, lng: -46.63, speed: 3),
      now: DateTime(2026, 1, 1, 12, 0, 0),
    );
    final jump = engine.process(
      _pos(lat: -23.56, lng: -46.63, speed: 1),
      now: DateTime(2026, 1, 1, 12, 0, 2),
    );
    expect(jump.accepted, isFalse);
    expect(jump.rejectReason, GpsRejectReason.jump);
    expect(engine.acceptedPoints.length, 1);
    expect(engine.distanceMeters, 0);
  });

  test('acumula distância geodésica entre pontos aceitos', () {
    final engine = GpsTrackingEngine(minDistanceMeters: 1);
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.process(_pos(lat: -23.55000, lng: -46.63000, speed: 3), now: t0);
    engine.process(
      _pos(lat: -23.55005, lng: -46.63000, speed: 3),
      now: t0.add(const Duration(seconds: 3)),
    );
    expect(engine.acceptedPoints.length, 2);
    expect(engine.distanceMeters, greaterThan(4));
    expect(engine.distanceMeters, lessThan(10));
  });

  test('detecta caminhada vs corrida pela velocidade', () {
    final engine = GpsTrackingEngine(minDistanceMeters: 1);
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.process(_pos(lat: -23.55, lng: -46.63, speed: 1.5), now: t0);
    final walk = engine.process(
      _pos(lat: -23.55005, lng: -46.63, speed: 1.5),
      now: t0.add(const Duration(seconds: 3)),
    );
    expect(walk.activity, MotionActivity.walk);

    final run = engine.process(
      _pos(lat: -23.55015, lng: -46.63, speed: 3.0),
      now: t0.add(const Duration(seconds: 6)),
    );
    expect(run.activity, MotionActivity.run);
  });

  test('exporta GPX com pontos', () {
    final points = [
      TrackedPoint(
        latitude: -23.55,
        longitude: -46.63,
        recordedAt: DateTime.utc(2026, 1, 1, 12),
        sequenceNum: 0,
        altitudeMeters: 760,
      ),
      TrackedPoint(
        latitude: -23.551,
        longitude: -46.631,
        recordedAt: DateTime.utc(2026, 1, 1, 12, 5),
        sequenceNum: 1,
        altitudeMeters: 765,
      ),
    ];
    final gpx = RunExportService.instance.buildGpx(
      points: points,
      title: 'Teste',
      startedAt: DateTime.utc(2026, 1, 1, 12),
      distanceMeters: 1500,
      elevationGainMeters: 5,
    );
    expect(gpx.contains('<gpx'), isTrue);
    expect(gpx.contains('<trkpt'), isTrue);
    expect(gpx.contains('Teste'), isTrue);

    final tcx = RunExportService.instance.buildTcx(
      points: points,
      title: 'Teste',
      startedAt: DateTime.utc(2026, 1, 1, 12),
      elapsedSec: 300,
      distanceMeters: 1500,
      elevationGainMeters: 5,
    );
    expect(tcx.contains('TrainingCenterDatabase'), isTrue);
    expect(tcx.contains('Trackpoint'), isTrue);
  });
}
