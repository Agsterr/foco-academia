import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Heading (0–360°) a partir de acelerômetro + magnetômetro (bússola).
///
/// Usa a mesma ideia do `SensorManager.getRotationMatrix` + `getOrientation`
/// do Android: azimute = direção do **topo do celular** (eixo Y) em relação
/// ao norte magnético — funciona com o aparelho na vertical (caminhada) e
/// deitado.
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

    // Vetor gravidade (acelerômetro) e campo magnético normalizados.
    var ax = a.x, ay = a.y, az = a.z;
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    if (normA < 1e-3) return;
    ax /= normA;
    ay /= normA;
    az /= normA;

    var mx = m.x, my = m.y, mz = m.z;
    final normM = math.sqrt(mx * mx + my * my + mz * mz);
    if (normM < 1e-3) return;
    mx /= normM;
    my /= normM;
    mz /= normM;

    // East = mag × gravity (produto vetorial).
    var ex = my * az - mz * ay;
    var ey = mz * ax - mx * az;
    var ez = mx * ay - my * ax;
    final normE = math.sqrt(ex * ex + ey * ey + ez * ez);
    // Campo magnético quase paralelo à gravidade → azimute instável.
    if (normE < 0.1) return;
    ex /= normE;
    ey /= normE;
    ez /= normE;

    // North = gravity × east.
    final nx = ay * ez - az * ey;
    final ny = az * ex - ax * ez;
    // nz não usado no azimute (getOrientation).

    // Azimuth: ângulo do eixo Y do aparelho (topo da tela) vs norte.
    // Equivale a atan2(R[1], R[4]) do Android com R = [E; N; A].
    var heading = math.atan2(ey, ny) * 180.0 / math.pi;
    if (heading < 0) heading += 360.0;

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

    var ex = my * az - mz * ay;
    var ey = mz * ax - mx * az;
    var ez = mx * ay - my * ax;
    final normE = math.sqrt(ex * ex + ey * ey + ez * ez);
    if (normE < 0.1) return null;
    ex /= normE;
    ey /= normE;
    ez /= normE;

    final ny = az * ex - ax * ez;
    var heading = math.atan2(ey, ny) * 180.0 / math.pi;
    if (heading < 0) heading += 360.0;
    return heading;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
