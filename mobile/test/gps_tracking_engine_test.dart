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
  });

  test('pausa manual congela movimento e acumula pausedSec', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.tickMovingTime(t0);
    engine.tickMovingTime(t0.add(const Duration(seconds: 1)));
    engine.tickMovingTime(t0.add(const Duration(seconds: 2)));
    expect(engine.movingElapsedSec, greaterThanOrEqualTo(1));

    engine.setManualPaused(true);
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

  test('cronômetro por relógio de parede não trava', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.markRunStarted(t0);
    engine.tickMovingTime(t0);
    expect(engine.movingElapsedSec, 0);
    engine.tickMovingTime(t0.add(const Duration(seconds: 5)));
    expect(engine.movingElapsedSec, 5);
    // Gap longo (Timer atrasado) — recupera tudo.
    engine.tickMovingTime(t0.add(const Duration(seconds: 40)));
    expect(engine.movingElapsedSec, 40);
  });

  test('velocidade sobe rápido com chip mesmo com passo GPS pequeno', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    engine.process(
      _pos(lat: -23.55000, lng: -46.63000, speed: 0),
      now: t0,
    );
    // Passo ~0,3 m em 0,5 s + chip 1,5 m/s (~5,4 km/h).
    engine.process(
      _pos(
        lat: -23.5500027,
        lng: -46.63000,
        speed: 1.5,
        accuracy: 8,
      ),
      now: t0.add(const Duration(milliseconds: 500)),
    );
    expect(engine.displaySpeedKmh, greaterThan(3.0));
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

  test('auto-pause opcional retoma por deslocamento', () {
    final engine = GpsTrackingEngine(
      enableAutoPause: true,
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

  test('auto-pause desligado por padrão — continua gravando parado/andando', () {
    final engine = GpsTrackingEngine();
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    for (var i = 0; i < 5; i++) {
      engine.process(
        _pos(lat: -23.55000, lng: -46.63000, speed: 0),
        now: t0.add(Duration(seconds: i * 10)),
      );
    }
    expect(engine.autoPaused, isFalse);
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
    expect(engine.displaySpeedKmh, lessThan(3.0));
    expect(engine.distanceMeters, lessThan(5));
  });

  test('caminhada gera muitos pontos (mapa segue a rua, não reta)', () {
    final engine = GpsTrackingEngine(
      minDistanceMeters: 1.5,
      minDistanceForKm: 2.0,
    );
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    // ~5 m por passo (acima do limiar de km).
    for (var i = 0; i < 25; i++) {
      engine.process(
        _pos(
          lat: -23.55000 - (i * 0.000045),
          lng: -46.63000 - ((i % 5) * 0.000005),
          speed: 1.5,
          accuracy: 6,
        ),
        now: t0.add(Duration(seconds: i * 3)),
      );
    }
    expect(engine.acceptedPoints.length, greaterThan(15));
    expect(engine.distanceMeters, greaterThan(80));
    expect(engine.displaySpeedKmh, greaterThan(3));
  });

  test('km não infla com jitter e média usa distância sólida', () {
    final engine = GpsTrackingEngine();
    engine.markRunStarted(DateTime(2026, 1, 1, 12, 0, 0));
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);
    // Zigzag de ~1,2 m (ruído típico) — não deve somar km.
    for (var i = 0; i < 20; i++) {
      final side = i.isEven ? 0.00001 : -0.00001;
      engine.process(
        _pos(
          lat: -23.55000 + (i * 0.000002),
          lng: -46.63000 + side,
          speed: 1.0,
          accuracy: 15,
        ),
        now: t0.add(Duration(seconds: i)),
      );
    }
    expect(engine.distanceMeters, lessThan(25));

    // 100 m em linha reta com boa precisão.
    for (var i = 0; i < 20; i++) {
      engine.process(
        _pos(
          lat: -23.55000 - (i * 0.000045), // ~5 m
          lng: -46.63000,
          speed: 1.5,
          accuracy: 8,
        ),
        now: t0.add(Duration(seconds: 30 + i * 3)),
      );
    }
    expect(engine.distanceMeters, greaterThan(70));
    expect(engine.distanceMeters, lessThan(120));
    engine.tickMovingTime(t0.add(const Duration(seconds: 100)));
    expect(engine.averageSpeedKmh, greaterThan(2));
    expect(engine.averageSpeedKmh, lessThan(15));
  });
}
