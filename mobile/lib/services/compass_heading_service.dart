import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

/// Heading (0–360°) a partir de acelerômetro + magnetômetro (bússola).
/// Usado para girar o mapa quando você vira o celular — como na tela de bloqueio.
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
        samplingPeriod: const Duration(milliseconds: 100),
      ).listen((e) {
        _accel = e;
        _recompute();
      });
      _magSub = magnetometerEventStream(
        samplingPeriod: const Duration(milliseconds: 100),
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

    // Tilt compensation (pitch/roll) + heading magnético.
    final ax = a.x, ay = a.y, az = a.z;
    final normA = math.sqrt(ax * ax + ay * ay + az * az);
    if (normA < 1e-6) return;
    final nx = ax / normA, ny = ay / normA, nz = az / normA;

    final pitch = math.asin(-nx.clamp(-1.0, 1.0));
    final roll = math.atan2(ny, nz);

    final mx = m.x, my = m.y, mz = m.z;
    final cosR = math.cos(roll), sinR = math.sin(roll);
    final cosP = math.cos(pitch), sinP = math.sin(pitch);

    final xh = mx * cosP + mz * sinP;
    final yh = mx * sinR * sinP + my * cosR - mz * sinR * cosP;
    var heading = math.atan2(-yh, xh) * 180.0 / math.pi;
    if (heading < 0) heading += 360.0;

    // Suaviza um pouco para o mapa não tremer.
    if (_heading == null) {
      _heading = heading;
    } else {
      var delta = heading - _heading!;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      _heading = (_heading! + delta * 0.25) % 360;
      if (_heading! < 0) _heading = _heading! + 360;
    }
    if (!_controller.isClosed) {
      _controller.add(_heading!);
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
