import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'package:foco_academia_mobile/services/distance_calculator_service.dart';
import 'package:foco_academia_mobile/services/gps_tracking_engine.dart';

void main() {
  group('DistanceCalculatorService', () {
    test('pathMeters soma segmentos', () {
      final d = DistanceCalculatorService.instance.pathMeters([
        (lat: -23.5, lng: -46.6),
        (lat: -23.501, lng: -46.6),
        (lat: -23.502, lng: -46.6),
      ]);
      expect(d, greaterThan(100));
      expect(d, lessThan(300));
    });

    test('averageSpeedKmh', () {
      final v = DistanceCalculatorService.instance.averageSpeedKmh(
        distanceMeters: 5000,
        movingElapsedSec: 1800,
      );
      expect(v, closeTo(10.0, 0.01));
    });
  });

  group('TrackedPoint rico', () {
    test('toJson inclui metadados', () {
      final p = TrackedPoint(
        latitude: -20.5,
        longitude: -47.4,
        recordedAt: DateTime.utc(2026, 1, 1),
        sequenceNum: 1,
        speedKmh: 10,
        accuracyMeters: 4.2,
        heading: 180,
        altitudeMeters: 845,
        provider: 'fused',
        isFiltered: false,
        verticalAccuracy: 3,
        bearingAccuracy: 5,
        speedAccuracy: 0.5,
      );
      final j = p.toJson();
      expect(j['accuracyMeters'], 4.2);
      expect(j['heading'], 180);
      expect(j['provider'], 'fused');
      expect(j['isFiltered'], false);
      expect(j['verticalAccuracy'], 3);
    });

    test('fromPosition preenche campos', () {
      final pos = Position(
        longitude: -47.4,
        latitude: -20.5,
        timestamp: DateTime.utc(2026, 1, 1),
        accuracy: 5,
        altitude: 800,
        altitudeAccuracy: 4,
        heading: 90,
        headingAccuracy: 10,
        speed: 2.5,
        speedAccuracy: 0.3,
      );
      final p = TrackedPoint.fromPosition(
        pos,
        recordedAt: DateTime.utc(2026, 1, 1),
        sequenceNum: 0,
        speedKmh: 9,
      );
      expect(p.accuracyMeters, 5);
      expect(p.heading, 90);
      expect(p.provider, 'fused');
      expect(p.altitudeMeters, 800);
    });
  });
}
