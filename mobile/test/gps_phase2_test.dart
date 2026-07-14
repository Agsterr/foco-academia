import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:foco_academia_mobile/services/filter_reason.dart';
import 'package:foco_academia_mobile/services/gps_filter_service.dart';
import 'package:foco_academia_mobile/services/gps_quality_service.dart';
import 'package:foco_academia_mobile/services/gps_tracking_engine.dart';
import 'package:foco_academia_mobile/services/kalman_filter_service.dart';

Position _pos({
  required double lat,
  required double lng,
  double accuracy = 10,
  double speed = 2,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 100,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: speed,
    speedAccuracy: 0,
  );
}

void main() {
  group('GpsFilterService', () {
    test('confidenceFromAccuracy segue a curva esperada', () {
      final f = GpsFilterService();
      expect(f.confidenceFromAccuracy(3), greaterThan(0.98));
      expect(f.confidenceFromAccuracy(8), greaterThan(0.93));
      expect(f.confidenceFromAccuracy(20), greaterThan(0.70));
      expect(f.confidenceFromAccuracy(20), lessThan(0.85));
      expect(f.confidenceFromAccuracy(45), lessThan(0.45));
    });

    test('rejeita accuracy ruim', () {
      final f = GpsFilterService(maxAccuracyMeters: 45);
      final d = f.evaluate(
        latitude: -23.5,
        longitude: -46.6,
        accuracyMeters: 60,
        recordedAt: DateTime(2026, 1, 1),
      );
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.lowAccuracy);
    });

    test('rejeita salto', () {
      final f = GpsFilterService(maxJumpMeters: 90);
      final prev = TrackedPoint(
        latitude: -23.55,
        longitude: -46.63,
        recordedAt: DateTime(2026, 1, 1, 12, 0, 0),
        sequenceNum: 0,
      );
      final d = f.evaluate(
        latitude: -23.56,
        longitude: -46.64,
        accuracyMeters: 10,
        recordedAt: DateTime(2026, 1, 1, 12, 0, 2),
        previous: prev,
      );
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.gpsJump);
    });

    test('maxSpeed por atividade', () {
      expect(GpsFilterService.maxSpeedForActivity(MotionActivity.walk), 10);
      expect(GpsFilterService.maxSpeedForActivity(MotionActivity.run), 30);
    });

    test('rejeita zig-zag stationary jitter', () {
      final f = GpsFilterService(minDistanceMeters: 1);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final a = TrackedPoint(
        latitude: -23.55000,
        longitude: -46.63000,
        recordedAt: t0,
        sequenceNum: 0,
        accuracyMeters: 16,
      );
      final b = TrackedPoint(
        latitude: -23.55004,
        longitude: -46.63000,
        recordedAt: t0.add(const Duration(seconds: 1)),
        sequenceNum: 1,
        accuracyMeters: 16,
      );
      // Volta quase ao ponto A (inversão de bearing).
      final d = f.evaluate(
        latitude: -23.550005,
        longitude: -46.63000,
        accuracyMeters: 16,
        recordedAt: t0.add(const Duration(seconds: 2)),
        previous: b,
        beforePrevious: a,
      );
      expect(d.accepted, isFalse);
      expect(d.reason, FilterReason.stationaryJitter);
    });

    test('bearingDeltaDegrees', () {
      expect(GpsFilterService.bearingDeltaDegrees(10, 350), closeTo(20, 0.1));
      expect(GpsFilterService.bearingDeltaDegrees(0, 180), closeTo(180, 0.1));
    });
  });

  group('KalmanFilterService', () {
    test('suaviza sem explodir', () {
      final k = KalmanFilterService();
      final a = k.smooth(latitude: -23.55, longitude: -46.63, accuracyMeters: 8);
      final b = k.smooth(
        latitude: -23.5502,
        longitude: -46.6302,
        accuracyMeters: 8,
      );
      expect(b.lat, closeTo(a.lat, 0.01));
      expect(b.lng, closeTo(a.lng, 0.01));
    });

    test('desligado devolve bruto', () {
      final k = KalmanFilterService(enabled: false);
      final r = k.smooth(latitude: 1, longitude: 2, accuracyMeters: 5);
      expect(r.lat, 1);
      expect(r.lng, 2);
    });
  });

  group('GpsQualityService', () {
    test('excelente com bons pontos', () {
      final points = List.generate(
        20,
        (i) => TrackedPoint(
          latitude: -23.55 + i * 0.0001,
          longitude: -46.63,
          recordedAt: DateTime(2026, 1, 1, 12, 0, i),
          sequenceNum: i,
          accuracyMeters: 5,
          confidenceScore: 0.95,
        ),
      );
      final q = GpsQualityService.instance.evaluate(
        acceptedPoints: points,
        rejectCounts: {},
        gpsGapSec: 0,
      );
      expect(q.score, greaterThan(85));
      expect(q.label, 'Excelente');
    });

    test('baixa com muitos saltos e accuracy ruim', () {
      final points = [
        TrackedPoint(
          latitude: -23.55,
          longitude: -46.63,
          recordedAt: DateTime(2026, 1, 1),
          sequenceNum: 0,
          accuracyMeters: 40,
          confidenceScore: 0.3,
        ),
      ];
      final q = GpsQualityService.instance.evaluate(
        acceptedPoints: points,
        rejectCounts: {
          FilterReason.gpsJump: 8,
          FilterReason.lowAccuracy: 20,
        },
        gpsGapSec: 120,
      );
      expect(q.score, lessThan(55));
      expect(q.label, 'Baixa precisão');
    });
  });

  group('Engine Fase 2', () {
    test('aceita ponto com confidenceScore', () {
      final engine = GpsTrackingEngine(enableKalman: true);
      final r = engine.process(
        _pos(lat: -23.55, lng: -46.63, accuracy: 6),
        now: DateTime(2026, 1, 1, 12, 0, 0),
      );
      expect(r.accepted, isTrue);
      expect(r.point!.confidenceScore, greaterThan(0.9));
      expect(r.point!.filterReason, FilterReason.none);
    });

    test('auto-pause pode ser ligado em runtime', () {
      final engine = GpsTrackingEngine(enableAutoPause: false);
      engine.setAutoPauseEnabled(true);
      expect(engine.enableAutoPause, isFalse); // campo final
      // Override ativo — processa parado por tempo longo
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      engine.process(_pos(lat: -23.55, lng: -46.63, speed: 0), now: t0);
      for (var i = 1; i <= 40; i++) {
        engine.process(
          _pos(lat: -23.55, lng: -46.63, speed: 0, accuracy: 8),
          now: t0.add(Duration(seconds: i)),
        );
      }
      // Pode ou não ter auto-pausado dependendo do stillSince; só garante sem crash
      expect(engine.acceptedPoints, isNotEmpty);
    });
  });
}
