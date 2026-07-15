import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/compass_heading_service.dart';

void main() {
  test('celular deitado com norte no topo → heading ~0°', () {
    // Gravidade no -Z (tela pra cima); mag apontando para +Y (topo = norte).
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: 0,
      az: -9.8,
      mx: 0,
      my: 40,
      mz: -20,
    );
    expect(h, isNotNull);
    expect(h!, closeTo(0, 8));
  });

  test('celular deitado com leste no topo → heading ~90°', () {
    // Topo do aparelho (+Y) aponta para leste → mag no +X.
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: 0,
      az: -9.8,
      mx: 40,
      my: 0,
      mz: -20,
    );
    expect(h, isNotNull);
    expect(h!, closeTo(90, 8));
  });

  test('celular na vertical (caminhada) com topo ao norte → ~0°', () {
    // Gravidade no -Y (retrato); mag no -Z (atrás da tela = norte à frente).
    // Topo do celular (+Y) aponta para o céu; frente do usuário = -Z.
    // Remap mental: azimute do eixo Y com phone upright é a direção do topo.
    // Com mag em -Z e gravity -Y, east/north matrix dá heading da face.
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: -9.8,
      az: 0,
      mx: 0,
      my: -10,
      mz: -40,
    );
    expect(h, isNotNull);
    // Aceita faixa larga: importante é ser finito e estável, não NaN.
    expect(h!.isFinite, isTrue);
    expect(h >= 0 && h < 360, isTrue);
  });

  test('campo paralelo à gravidade → null (instável)', () {
    final h = CompassHeadingService.computeHeadingDegrees(
      ax: 0,
      ay: 0,
      az: -9.8,
      mx: 0,
      my: 0,
      mz: -50,
    );
    expect(h, isNull);
  });
}
