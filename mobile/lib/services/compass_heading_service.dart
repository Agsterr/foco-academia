import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Heading (0–360°) estilo Google Maps: fusão giroscópio + bússola.
///
/// O magnetômetro sozinho treme parado (interferência / ruído). O Maps usa o
/// *rotation vector* do SO (accel + gyro + mag). Aqui replicamos a ideia com
/// `sensors_plus`:
/// - **Giroscópio** manda no curto prazo (giro do celular responde na hora).
/// - **Accel + mag** corrigem o norte no longo prazo (sem drift).
/// - Parado (|ω| baixo): **congela** o heading — não deixa a seta oscilar.
///
/// Remap por inclinação (igual ao `remapCoordinateSystem` do Android):
/// - **Deitado** (tela pra cima): azimute do **topo** do celular (+Y).
/// - **Vertical** (caminhada): azimute da **frente** (−Z).
class CompassHeadingService {
  CompassHeadingService._();
  static final instance = CompassHeadingService._();

  /// Abaixo disso (°/s) o celular está “parado” → ignora tremor do mag.
  static const double stillYawRateDegPerSec = 4.0;

  /// Acima disso (°/s) confia quase só no gyro (giro rápido do pulso).
  static const double turningYawRateDegPerSec = 25.0;

  /// Correção máxima do mag por segundo quando parado (quase zero).
  static const double stillMagBlendPerSec = 0.015;

  /// Correção do mag por segundo em movimento normal.
  static const double movingMagBlendPerSec = 0.12;

  /// Correção do mag por segundo girando rápido (só anti-drift leve).
  static const double turningMagBlendPerSec = 0.04;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  AccelerometerEvent? _accel;
  MagnetometerEvent? _mag;
  double? _heading;
  DateTime? _lastGyroAt;
  final _controller = StreamController<double>.broadcast();

  Stream<double> get stream => _controller.stream;
  double? get headingDegrees => _heading;

  bool get isRunning =>
      _accelSub != null || _magSub != null || _gyroSub != null;

  void start() {
    if (isRunning) return;
    const period = Duration(milliseconds: 40);
    try {
      _accelSub = accelerometerEventStream(samplingPeriod: period).listen((e) {
        _accel = e;
        // Sem gyro ainda: bootstrap com mag (aparelhos sem giroscópio).
        if (_lastGyroAt == null) _recomputeFromMagOnly();
      });
      _magSub = magnetometerEventStream(samplingPeriod: period).listen((e) {
        _mag = e;
        if (_lastGyroAt == null) _recomputeFromMagOnly();
      });
      _gyroSub = gyroscopeEventStream(samplingPeriod: period).listen(_onGyro);
    } catch (_) {
      // Sem sensores — só GPS heading.
    }
  }

  void stop() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _gyroSub?.cancel();
    _accelSub = null;
    _magSub = null;
    _gyroSub = null;
    _accel = null;
    _mag = null;
    _heading = null;
    _lastGyroAt = null;
  }

  void _onGyro(GyroscopeEvent g) {
    final now = DateTime.now();
    final prev = _lastGyroAt;
    _lastGyroAt = now;
    if (prev == null) {
      _recomputeFromMagOnly();
      return;
    }

    var dt = now.difference(prev).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.25) {
      // Gap grande (app em background) — ressincroniza no mag.
      _recomputeFromMagOnly();
      return;
    }

    final a = _accel;
    final m = _mag;
    if (a == null || m == null) return;

    final magHeading = computeHeadingDegrees(
      ax: a.x,
      ay: a.y,
      az: a.z,
      mx: m.x,
      my: m.y,
      mz: m.z,
    );
    if (magHeading == null) return;

    // Taxa de guinada = componente do gyro ao longo da gravidade (eixo vertical).
    final normA = math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
    if (normA < 1e-3) return;
    final gx = a.x / normA;
    final gy = a.y / normA;
    final gz = a.z / normA;
    // GyroscopeEvent: rad/s no referencial do aparelho.
    final yawRateRad = g.x * gx + g.y * gy + g.z * gz;
    final yawRateDeg = yawRateRad * 180.0 / math.pi;
    final absRate = yawRateDeg.abs();

    if (_heading == null) {
      _heading = magHeading;
      _emit();
      return;
    }

    // Integra o gyro (suave, sem tremor).
    var predicted = (_heading! + yawRateDeg * dt) % 360.0;
    if (predicted < 0) predicted += 360.0;

    // Peso do mag conforme “estou girando?” — parado = quase não corrige.
    final double magPerSec;
    if (absRate < stillYawRateDegPerSec) {
      magPerSec = stillMagBlendPerSec;
    } else if (absRate > turningYawRateDegPerSec) {
      magPerSec = turningMagBlendPerSec;
    } else {
      // Interpola entre still e moving.
      final t = (absRate - stillYawRateDegPerSec) /
          (turningYawRateDegPerSec - stillYawRateDegPerSec);
      magPerSec = stillMagBlendPerSec +
          (movingMagBlendPerSec - stillMagBlendPerSec) * t;
    }

    var beta = (magPerSec * dt).clamp(0.0, 1.0);
    // Rejeita saltos absurdos do mag (interferência perto de metal).
    final magDelta = _circularDelta(magHeading, predicted).abs();
    if (magDelta > 45 && absRate < turningYawRateDegPerSec) {
      beta *= 0.15;
    }

    _heading = _lerpAngle(predicted, magHeading, beta);
    _emit();
  }

  /// Fallback sem gyro (ou bootstrap): EMA forte no mag, sem oscilar tanto.
  void _recomputeFromMagOnly() {
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

    if (_heading == null) {
      _heading = heading;
    } else {
      final delta = _circularDelta(heading, _heading!);
      final abs = delta.abs();
      // Mais inerte que a versão antiga: evita “lá e pra cá” parado.
      final alpha = abs > 40
          ? 0.45
          : abs > 15
              ? 0.22
              : abs > 4
                  ? 0.08
                  : 0.03;
      _heading = (_heading! + delta * alpha) % 360;
      if (_heading! < 0) _heading = _heading! + 360;
    }
    _emit();
  }

  void _emit() {
    final h = _heading;
    if (h == null || _controller.isClosed) return;
    _controller.add(h);
  }

  /// Delta circular de [from] → [to] em (−180, 180].
  static double _circularDelta(double to, double from) {
    var d = to - from;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  static double _lerpAngle(double from, double to, double t) {
    final d = _circularDelta(to, from);
    var out = (from + d * t) % 360.0;
    if (out < 0) out += 360.0;
    return out;
  }

  /// Recalcula heading síncrono a partir de accel + mag (útil em testes).
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

    // Blend suave flat ↔ upright (evita flip brusco perto de ~45°).
    final upright = ay.abs();
    final flat = az.abs();
    final sum = upright + flat;
    final uprightWeight = sum < 1e-6 ? 0.0 : (upright / sum).clamp(0.0, 1.0);

    final flatRad = math.atan2(ey, ny);
    final uprightRad = math.atan2(-ez, -nz);
    // Interpola no círculo unitário (não na média linear de ângulos).
    final c = (1 - uprightWeight) * math.cos(flatRad) +
        uprightWeight * math.cos(uprightRad);
    final s = (1 - uprightWeight) * math.sin(flatRad) +
        uprightWeight * math.sin(uprightRad);
    var heading = math.atan2(s, c) * 180.0 / math.pi;
    if (heading < 0) heading += 360.0;
    return heading;
  }

  /// Integra yaw do gyro e corrige com mag (exposto p/ testes).
  static double fuseGyroMagHeading({
    required double currentHeading,
    required double yawRateDegPerSec,
    required double magHeading,
    required double dtSeconds,
  }) {
    if (dtSeconds <= 0) return currentHeading;
    var predicted = (currentHeading + yawRateDegPerSec * dtSeconds) % 360.0;
    if (predicted < 0) predicted += 360.0;

    final absRate = yawRateDegPerSec.abs();
    final double magPerSec;
    if (absRate < stillYawRateDegPerSec) {
      magPerSec = stillMagBlendPerSec;
    } else if (absRate > turningYawRateDegPerSec) {
      magPerSec = turningMagBlendPerSec;
    } else {
      final t = (absRate - stillYawRateDegPerSec) /
          (turningYawRateDegPerSec - stillYawRateDegPerSec);
      magPerSec = stillMagBlendPerSec +
          (movingMagBlendPerSec - stillMagBlendPerSec) * t;
    }
    var beta = (magPerSec * dtSeconds).clamp(0.0, 1.0);
    final magDelta = _circularDelta(magHeading, predicted).abs();
    if (magDelta > 45 && absRate < turningYawRateDegPerSec) {
      beta *= 0.15;
    }
    return _lerpAngle(predicted, magHeading, beta);
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
