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
      // Frente = leste (−Z = leste) → mag horizontal em −Z? 
      // X = norte quando frente = leste? 
      // Device: X=right=south when facing east? Facing east: X→south, Y→up, −Z→east.
      // Mag north = −X direction → mx negative; dip −Y.
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
}
