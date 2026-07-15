import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Heading (0–360°) a partir de acelerômetro + magnetômetro (bússola).
///
/// Mesma ideia do `SensorManager.getRotationMatrix` + `getOrientation` do
/// Android, com remap por inclinação:
/// - **Deitado** (tela pra cima): azimute do **topo** do celular (+Y).
/// - **Vertical** (caminhada, celular na frente): azimute da **frente** (−Z),
///   como `remapCoordinateSystem(R, AXIS_X, AXIS_MINUS_Z)`.
///
/// Sem o remap, na vertical o eixo Y aponta para o céu e o azimute fica
/// instável / ~90° errado — a seta “de lado” no mapa.
class CompassHeadingService {
  CompassHeadingService._();
  static final instance = CompassHeadingService._();

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  AccelerometerEvent? _accel;
  MagnetometerEvent? _mag;
  double? _heading;
  final _controller = StreamController<double>.broadcast();

  Stream<double> get stream => _controller.stream;
  double? get headingDegrees => _heading;

  bool get isRunning => _accelSub != null || _magSub != null;

  void start() {
    if (isRunning) return;
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 80),
      ).listen((e) {
        _accel = e;
        _recompute();
      });
      _magSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 80),
      ).listen((e) {
        _mag = e;
        _recompute();
      });
    } catch (_) {
      // Sem sensores — só GPS heading.
    }
  }

  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _accelSub = null;
    _magSub = null;
  }

  void _recompute() {
    final a = _accel;
    final m = _mag;
    if (a == null || m == null) return;

    final heading = computeHeadingDegrees(
      ax: a.x,
      ay: a.y,
      az: a.z,
      mx: m.x,
      my: m.y,
      mz: m.z,
    );
    if (heading == null) return;

    // Suavização adaptativa: gira rápido quando o celular vira de verdade,
    // filtra tremor fino (evita “travar” e seta de lado).
    if (_heading == null) {
      _heading = heading;
    } else {
      var delta = heading - _heading!;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      final abs = delta.abs();
      final alpha = abs > 35
          ? 0.55
          : abs > 12
              ? 0.35
              : 0.18;
      _heading = (_heading! + delta * alpha) % 360;
      if (_heading! < 0) _heading = _heading! + 360;
    }
    if (!_controller.isClosed) {
      _controller.add(_heading!);
    }
  }

  /// Recalcula heading síncrono (útil em testes).
  ///
  /// [ax]/ay]/az] no mesmo referencial do acelerômetro do aparelho
  /// (Android: ~+g no eixo que aponta para cima).
  static double? computeHeadingDegrees({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    if (normA < 1e-3) return null;
    ax /= normA;
    ay /= normA;
    az /= normA;

    final normM = math.sqrt(mx * mx + my * my + mz * mz);
    if (normM < 1e-3) return null;
    mx /= normM;
    my /= normM;
    mz /= normM;

    // East = mag × gravity (produto vetorial).
    var ex = my * az - mz * ay;
    var ey = mz * ax - mx * az;
    var ez = mx * ay - my * ax;
    final normE = math.sqrt(ex * ex + ey * ey + ez * ez);
    // Campo magnético quase paralelo à gravidade → azimute instável.
    if (normE < 0.1) return null;
    ex /= normE;
    ey /= normE;
    ez /= normE;

    // North = gravity × east.
    final nx = ay * ez - az * ey;
    final ny = az * ex - ax * ez;
    final nz = ax * ey - ay * ex;

    // Inclinação: |ay| alto = vertical (retrato); |az| alto = deitado.
    // Na vertical o topo (+Y) aponta pro céu — azimute de Y é inútil.
    // Usamos a frente do aparelho (−Z), direção da caminhada com a tela
    // virada para o usuário.
    final upright = ay.abs();
    final flat = az.abs();
    final double headingRad;
    if (upright >= flat) {
      // Frente (−Z): equivalente a AXIS_X + AXIS_MINUS_Z no Android.
      headingRad = math.atan2(-ez, -nz);
    } else {
      // Topo da tela (+Y).
      headingRad = math.atan2(ey, ny);
    }

    var heading = headingRad * 180.0 / math.pi;
    if (heading < 0) heading += 360.0;
    return heading;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
