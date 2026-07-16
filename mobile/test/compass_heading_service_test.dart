import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/compass_heading_service.dart';

void main() {
  group('celular deitado (acelerômetro +Z ≈ +g)', () {
    test('topo ao norte → heading ~0°', () {
      // Tela pra cima; topo (+Y) = norte; mag com componente em +Y.
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 0,
        az: 9.8,
        mx: 0,
        my: 40,
        mz: -20,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(0, 8));
    });

    test('topo ao leste → heading ~90°', () {
      // Topo (+Y) = leste ⇒ direita (+X) = sul ⇒ norte = −X.
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 0,
        az: 9.8,
        mx: -40,
        my: 0,
        mz: -20,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(90, 8));
    });

    test('topo ao sul → heading ~180°', () {
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 0,
        az: 9.8,
        mx: 0,
        my: -40,
        mz: -20,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(180, 8));
    });
  });

  group('celular na vertical / caminhada (acelerômetro +Y ≈ +g)', () {
    test('frente (−Z) ao norte → heading ~0°', () {
      // Retrato: Y pra cima. Usuário olha a tela e caminha para o norte
      // (frente do aparelho = −Z = norte). Mag: norte em −Z + dip em −Y.
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 9.8,
        az: 0,
        mx: 0,
        my: -10,
        mz: -40,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(0, 12));
    });

    test('frente (−Z) ao leste → heading ~90°', () {
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 9.8,
        az: 0,
        mx: -40,
        my: -10,
        mz: 0,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(90, 12));
    });

    test('frente (−Z) ao sul → heading ~180°', () {
      // Facing south: −Z = south, X = west, mag north = +Z.
      final h = CompassHeadingService.computeHeadingDegrees(
        ax: 0,
        ay: 9.8,
        az: 0,
        mx: 0,
        my: -10,
        mz: 40,
      );
      expect(h, isNotNull);
      expect(h!, closeTo(180, 12));
    });
  });

  test('campo paralelo à gravidade → null (instável)', () {
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: 0,
      az: 9.8,
      mx: 0,
      my: 0,
      mz: 50,
    );
    expect(h, isNull);
  });

  group('fusão gyro + mag (estilo Maps)', () {
    test('parado: ruído do mag quase não mexe o heading', () {
      // Mag “treme” ±8° mas yawRate ≈ 0 → heading quase congelado.
      var h = 90.0;
      for (var i = 0; i < 40; i++) {
        final noisyMag = 90.0 + (i.isEven ? 8.0 : -8.0);
        h = CompassHeadingService.fuseGyroMagHeading(
          currentHeading: h,
          yawRateDegPerSec: 0.3,
          magHeading: noisyMag,
          dtSeconds: 0.04,
        );
      }
      expect(h, closeTo(90, 3));
    });

    test('giro real do celular: heading acompanha o gyro', () {
      // 90°/s por 0.5 s = +45°; mag fica no valor antigo (atrasado).
      var h = 0.0;
      for (var i = 0; i < 12; i++) {
        h = CompassHeadingService.fuseGyroMagHeading(
          currentHeading: h,
          yawRateDegPerSec: 90.0,
          magHeading: 0.0,
          dtSeconds: 0.04,
        );
      }
      // ~43° (gyro) com leve puxão do mag → ainda bem perto de 45°.
      expect(h, greaterThan(35));
      expect(h, lessThan(50));
    });

    test('cruzando 0°/360° sem salto', () {
      final h = CompassHeadingService.fuseGyroMagHeading(
        currentHeading: 358.0,
        yawRateDegPerSec: 50.0,
        magHeading: 5.0,
        dtSeconds: 0.04,
      );
      // 358 + 2 = 360 → 0, com blend leve pro mag em 5°.
      expect(h, lessThan(12));
      expect(h, greaterThanOrEqualTo(0));
    });
  });

  test('inclinação intermediária: blend flat/upright contínuo', () {
    // ~45°: ay ≈ az — não deve explodir / retornar null.
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: 6.9,
      az: 6.9,
      mx: 0,
      my: 20,
      mz: -30,
    );
    expect(h, isNotNull);
    expect(h!, greaterThanOrEqualTo(0));
    expect(h, lessThan(360));
  });
}
