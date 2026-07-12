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

  test('detecta caminhada vs corrida pela velocidade de deslocamento', () {
    final engine = GpsTrackingEngine(minDistanceMeters: 1);
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    // ~5.4 km/h
    for (var i = 0; i < 8; i++) {
      engine.process(
        _pos(
          lat: -23.55 - (i * 0.000027),
          lng: -46.63,
          speed: 1.5,
        ),
        now: t0.add(Duration(seconds: i * 2)),
      );
    }
    expect(engine.currentActivity, MotionActivity.walk);

    // ~10.8 km/h
    for (var i = 8; i < 16; i++) {
      engine.process(
        _pos(
          lat: -23.55 - (8 * 0.000027) - ((i - 8) * 0.000054),
          lng: -46.63,
          speed: 3.0,
        ),
        now: t0.add(Duration(seconds: i * 2)),
      );
    }
    expect(engine.currentActivity, MotionActivity.run);
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

    final tcx = RunExportService.instance.buildTcx(
      points: points,
      title: 'Teste',
      startedAt: DateTime.utc(2026, 1, 1, 12),
      elapsedSec: 300,
      distanceMeters: 1500,
      elevationGainMeters: 5,
    );
    expect(tcx.contains('TrainingCenterDatabase'), isTrue);
  });

  test('pausa manual congela movimento e acumula pausedSec', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.tickMovingTime(t0);
    engine.tickMovingTime(t0.add(const Duration(seconds: 1)));
    engine.tickMovingTime(t0.add(const Duration(seconds: 2)));
    expect(engine.movingElapsedSec, greaterThanOrEqualTo(1));

    engine.setManualPaused(true);
    expect(engine.pauseCount, 1);

    final beforeMove = engine.movingElapsedSec;
    engine.tickMovingTime(t0.add(const Duration(seconds: 3)));
    engine.tickMovingTime(t0.add(const Duration(seconds: 4)));
    expect(engine.movingElapsedSec, beforeMove);
    expect(engine.pausedSec, greaterThanOrEqualTo(1));

    final rejected = engine.process(
      _pos(lat: -23.55, lng: -46.63, speed: 3),
      now: t0.add(const Duration(seconds: 5)),
    );
    expect(rejected.rejectReason, GpsRejectReason.manualPaused);

    engine.setManualPaused(false);
    engine.tickMovingTime(t0.add(const Duration(seconds: 6)));
    engine.tickMovingTime(t0.add(const Duration(seconds: 7)));
    expect(engine.movingElapsedSec, greaterThan(beforeMove));
  });

  test('cronômetro recupera gap longo (tela apagada / timer atrasado)', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.tickMovingTime(t0);
    engine.tickMovingTime(t0.add(const Duration(seconds: 1)));
    expect(engine.movingElapsedSec, 1);
    engine.tickMovingTime(t0.add(const Duration(seconds: 26)));
    expect(engine.movingElapsedSec, 26);
  });

  test('fixixa ruim ainda marca sinal GPS (lastRawFixAt)', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime.now();
    engine.process(_pos(lat: -23.55, lng: -46.63), now: t0);
    final bad = engine.process(
      _pos(lat: -23.5501, lng: -46.6301, accuracy: 80, speed: 0),
      now: t0.add(const Duration(seconds: 3)),
    );
    expect(bad.accepted, isFalse);
    expect(engine.hasGpsSignal, isTrue);
  });

  test('auto-pause retoma por deslocamento mesmo com speed 0', () {
    final engine = GpsTrackingEngine(
      autoPauseAfter: const Duration(seconds: 2),
      resumeDisplacementMeters: 8,
      minDistanceMeters: 1,
    );
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.process(
      _pos(lat: -23.55000, lng: -46.63000, speed: 0),
      now: t0,
    );
    engine.process(
      _pos(lat: -23.55000, lng: -46.63000, speed: 0),
      now: t0.add(const Duration(seconds: 3)),
    );
    expect(engine.autoPaused, isTrue);

    final resume = engine.process(
      _pos(lat: -23.55010, lng: -46.63000, speed: 0, accuracy: 12),
      now: t0.add(const Duration(seconds: 8)),
    );
    expect(engine.autoPaused, isFalse);
    expect(resume.accepted, isTrue);
  });

  test('após gap longo reancora sem somar teleporte na distância', () {
    final engine = GpsTrackingEngine(minDistanceMeters: 1);
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.process(
      _pos(lat: -23.55000, lng: -46.63000, speed: 2),
      now: t0,
    );
    final before = engine.distanceMeters;
    final second = engine.process(
      _pos(lat: -23.55100, lng: -46.63000, speed: 2, accuracy: 10),
      now: t0.add(const Duration(seconds: 40)),
    );
    expect(second.accepted, isTrue);
    expect(engine.acceptedPoints.length, 2);
    expect(engine.distanceMeters, before);
  });

  test('parado com drift do GPS não alonga a rota nem marca correndo', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    for (var i = 0; i < 8; i++) {
      engine.process(
        _pos(
          lat: -23.55000 + (i * 0.000001),
          lng: -46.63000,
          speed: 4.0,
          accuracy: 12,
        ),
        now: t0.add(Duration(seconds: i)),
      );
    }
    expect(engine.displaySpeedKmh, lessThan(2.0));
    expect(engine.currentActivity, MotionActivity.stopped);
    expect(engine.distanceMeters, lessThan(5));
  });

  test('após parado retoma caminhada com poucos metros', () {
    final engine = GpsTrackingEngine(
      autoPauseAfter: const Duration(seconds: 2),
      minDistanceMeters: 1,
    );
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    for (var i = 0; i < 4; i++) {
      engine.process(
        _pos(lat: -23.55000, lng: -46.63000, speed: 0),
        now: t0.add(Duration(seconds: i)),
      );
    }
    expect(engine.autoPaused, isTrue);

    for (var i = 1; i <= 5; i++) {
      // Simula movimento do telefone (acelerômetro) + GPS.
      engine.notePhoneAcceleration(2, 3, 11, now: t0.add(Duration(seconds: 10 + i * 2)));
      engine.process(
        _pos(
          lat: -23.55000 - (i * 0.000032),
          lng: -46.63000,
          speed: 1.4,
          accuracy: 10,
        ),
        now: t0.add(Duration(seconds: 10 + i * 2)),
      );
    }
    expect(engine.autoPaused, isFalse);
    expect(engine.currentActivity, MotionActivity.walk);
    expect(engine.distanceMeters, greaterThan(3));
  });

  test('acelerômetro impede auto-pause falso durante caminhada lenta', () {
    final engine = GpsTrackingEngine(
      autoPauseAfter: const Duration(seconds: 3),
      minDistanceMeters: 1,
    );
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    for (var i = 0; i < 6; i++) {
      engine.notePhoneAcceleration(1.5, 2.0, 11.5, now: t0.add(Duration(seconds: i)));
      engine.process(
        _pos(
          lat: -23.55000 - (i * 0.00001), // ~1.1 m/passo — lento
          lng: -46.63000,
          speed: 0.4,
          accuracy: 12,
        ),
        now: t0.add(Duration(seconds: i)),
      );
    }
    expect(engine.autoPaused, isFalse);
  });
}
