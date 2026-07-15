import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/gps_diagnostic.dart';
import 'package:foco_academia_mobile/services/location_permission_helper.dart';

void main() {
  group('EnergyThreatStatus', () {
    test('economia OU otimização ameaçam GPS em background', () {
      expect(
        const EnergyThreatStatus(
          batteryOptimized: true,
          powerSaverOn: false,
        ).threatensBackgroundGps,
        isTrue,
      );
      expect(
        const EnergyThreatStatus(
          batteryOptimized: false,
          powerSaverOn: true,
        ).threatensBackgroundGps,
        isTrue,
      );
      expect(
        const EnergyThreatStatus(
          batteryOptimized: false,
          powerSaverOn: false,
        ).threatensBackgroundGps,
        isFalse,
      );
    });

    test('mensagens cobrem os dois casos', () {
      final both = const EnergyThreatStatus(
        batteryOptimized: true,
        powerSaverOn: true,
      ).shortWarning!;
      expect(both.toLowerCase(), contains('economia'));

      final saver = const EnergyThreatStatus(
        batteryOptimized: false,
        powerSaverOn: true,
      ).shortWarning!;
      expect(saver.toLowerCase(), contains('economia'));

      final opt = const EnergyThreatStatus(
        batteryOptimized: true,
        powerSaverOn: false,
      ).shortWarning!;
      expect(opt.toLowerCase(), contains('otimiza'));

      expect(
        const EnergyThreatStatus(
          batteryOptimized: false,
          powerSaverOn: false,
        ).shortWarning,
        isNull,
      );
    });
  });

  test('POWER_SAVER_MODE apiName', () {
    expect(GpsDiagnosticEvent.powerSaverMode.apiName, 'POWER_SAVER_MODE');
  });

  test('EnergySettingsLauncher channel name is estável', () {
    // Garante que a API pública existe sem depender de platform channel.
    expect(EnergySettingsLauncher.openBatterySaverSettings, isA<Function>());
    expect(
      EnergySettingsLauncher.openIgnoreBatteryOptimizations,
      isA<Function>(),
    );
  });
}
