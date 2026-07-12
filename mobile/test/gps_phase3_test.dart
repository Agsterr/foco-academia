import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/gps_config.dart';
import 'package:foco_academia_mobile/services/gps_diagnostic.dart';
import 'package:foco_academia_mobile/services/gps_tracking_engine.dart';

void main() {
  group('GpsConfig', () {
    test('defaults e versionSnapshot', () {
      const c = GpsConfig.defaults;
      expect(c.kalmanEnabled, isTrue);
      expect(c.gpsAlgorithmVersion, '1');
      expect(c.versionSnapshot()['filterVersion'], '1');
    });

    test('copyWith preserva versões', () {
      final c = GpsConfig.defaults.copyWith(autoPauseEnabled: true, maxSpeed: 25);
      expect(c.autoPauseEnabled, isTrue);
      expect(c.maxSpeed, 25);
      expect(c.filterVersion, '1');
    });

    test('fromJson roundtrip parcial', () {
      final c = GpsConfig.fromJson({
        'kalmanEnabled': false,
        'minAccuracy': 30,
      });
      expect(c.kalmanEnabled, isFalse);
      expect(c.minAccuracy, 30);
      expect(c.jumpDetectionEnabled, isTrue);
    });
  });

  group('GpsDiagnosticEvent', () {
    test('apiName', () {
      expect(GpsDiagnosticEvent.gpsLost.apiName, 'GPS_LOST');
      expect(GpsDiagnosticEvent.permissionDenied.apiName, 'PERMISSION_DENIED');
    });

    test('toJson', () {
      final r = GpsDiagnosticEventRecord(
        eventType: GpsDiagnosticEvent.gpsRecovered,
        timestamp: DateTime.utc(2026, 1, 1),
        message: 'ok',
        latitude: -20.5,
        clientSessionId: 'abc',
      );
      expect(r.toJson()['eventType'], 'GPS_RECOVERED');
      expect(r.toJson()['clientSessionId'], 'abc');
    });
  });

  group('Engine applyConfig', () {
    test('aplica flags', () {
      final engine = GpsTrackingEngine();
      engine.applyConfig(
        GpsConfig.defaults.copyWith(
          kalmanEnabled: false,
          jumpDetectionEnabled: false,
          minAccuracy: 60,
        ),
      );
      expect(engine.kalman.enabled, isFalse);
      expect(engine.filter.jumpDetectionEnabled, isFalse);
      expect(engine.filter.maxAccuracyMeters, 60);
    });
  });
}
