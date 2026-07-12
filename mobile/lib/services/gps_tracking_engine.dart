import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

/// Ponto aceito após filtros de qualidade GPS.
class TrackedPoint {
  const TrackedPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    required this.sequenceNum,
    this.speedKmh,
    this.accuracyMeters,
    this.altitudeMeters,
    this.activity,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final int sequenceNum;
  final double? speedKmh;
  final double? accuracyMeters;
  final double? altitudeMeters;
  final MotionActivity? activity;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'speedKmh': speedKmh,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'sequenceNum': sequenceNum,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (altitudeMeters != null) 'altitudeMeters': altitudeMeters,
        if (activity != null) 'activity': activity!.name,
      };

  factory TrackedPoint.fromJson(Map<String, dynamic> json) {
    MotionActivity? activity;
    final raw = json['activity'] as String?;
    if (raw != null) {
      for (final e in MotionActivity.values) {
        if (e.name == raw) {
          activity = e;
          break;
        }
      }
    }
    return TrackedPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKmh: (json['speedKmh'] as num?)?.toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
      altitudeMeters: (json['altitudeMeters'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      sequenceNum: (json['sequenceNum'] as num?)?.toInt() ?? 0,
      activity: activity,
    );
  }
}

enum MotionActivity { stopped, walk, run }

enum GpsRejectReason {
  accuracy,
  speed,
  jump,
  tooSoon,
  autoPaused,
  manualPaused,
}

class KmSplit {
  const KmSplit({
    required this.km,
    required this.movingSecAtSplit,
    required this.splitSec,
    required this.paceSecPerKm,
    this.elevationGainMeters = 0,
  });

  final int km;
  final int movingSecAtSplit;
  final int splitSec;
  final double paceSecPerKm;
  final double elevationGainMeters;

  Map<String, dynamic> toJson() => {
        'km': km,
        'movingSecAtSplit': movingSecAtSplit,
        'splitSec': splitSec,
        'paceSecPerKm': paceSecPerKm,
        'elevationGainMeters': elevationGainMeters,
      };

  factory KmSplit.fromJson(Map<String, dynamic> json) => KmSplit(
        km: (json['km'] as num).toInt(),
        movingSecAtSplit: (json['movingSecAtSplit'] as num).toInt(),
        splitSec: (json['splitSec'] as num).toInt(),
        paceSecPerKm: (json['paceSecPerKm'] as num).toDouble(),
        elevationGainMeters:
            (json['elevationGainMeters'] as num?)?.toDouble() ?? 0,
      );
}

class GpsProcessResult {
  const GpsProcessResult.accepted({
    required this.point,
    required this.deltaMeters,
    required this.activity,
    this.newSplit,
  })  : accepted = true,
        rejectReason = null,
        autoPaused = false,
        manualPaused = false;

  const GpsProcessResult.rejected(
    this.rejectReason, {
    this.activity = MotionActivity.stopped,
    this.autoPaused = false,
    this.manualPaused = false,
  })  : accepted = false,
        point = null,
        deltaMeters = null,
        newSplit = null;

  final bool accepted;
  final TrackedPoint? point;
  final double? deltaMeters;
  final GpsRejectReason? rejectReason;
  final MotionActivity activity;
  final bool autoPaused;
  final bool manualPaused;
  final KmSplit? newSplit;

  bool get isPaused => autoPaused || manualPaused;
}

/// Tracking GPS pragmático (funciona no telefone real):
/// - Rota = pontos brutos (só rejeita lixo óbvio)
/// - Velocidade = deslocamento real + chip
/// - Auto-pause OFF por padrão (como Strava recomenda em caminhada)
/// - Sem Kalman na rota (atrasava e travava distância/mapa)
class GpsTrackingEngine {
  GpsTrackingEngine({
    this.maxAccuracyMeters = 45,
    this.relaxedAccuracyMeters = 70,
    this.maxSpeedKmh = 40,
    this.maxJumpMeters = 90,
    this.minDistanceMeters = 1.0,
    this.bufferSize = 40,
    this.smoothWindow = 3,
    this.gpsLossTimeout = const Duration(seconds: 45),
    this.pauseBelowKmh = 1.0,
    this.resumeAboveKmh = 1.5,
    this.resumeDisplacementMeters = 4,
    this.autoPauseAfter = const Duration(seconds: 30),
    this.enableAutoPause = false,
    this.runEnterKmh = 8.0,
    this.runExitKmh = 6.0,
  });

  final double maxAccuracyMeters;
  final double relaxedAccuracyMeters;
  final double maxSpeedKmh;
  final double maxJumpMeters;
  final double minDistanceMeters;
  final int bufferSize;
  final int smoothWindow;
  final Duration gpsLossTimeout;
  final double pauseBelowKmh;
  final double resumeAboveKmh;
  final double resumeDisplacementMeters;
  final Duration autoPauseAfter;
  /// Desligado por padrão: auto-pause no celular trava corrida/caminhada.
  final bool enableAutoPause;
  final double runEnterKmh;
  final double runExitKmh;

  double distanceMeters = 0;
  double estimatedGapMeters = 0;
  double elevationGainMeters = 0;
  int sequenceNum = 0;
  int movingElapsedSec = 0;
  int pausedSec = 0;
  int pauseCount = 0;
  DateTime? lastFixAt;
  DateTime? lastRawFixAt;
  double? lastValidSpeedKmh;
  bool autoPaused = false;
  bool manualPaused = false;
  MotionActivity currentActivity = MotionActivity.stopped;

  TrackedPoint? _lastAccepted;
  DateTime? _stillSince;
  DateTime? _lastMovingTickAt;
  DateTime? _pauseTickAt;
  double _distanceAtLastSplit = 0;
  int _movingSecAtLastSplit = 0;
  double _elevAtLastSplit = 0;
  double? _lastAltitude;

  double? _lastRawLat;
  double? _lastRawLng;
  DateTime? _lastRawAt;
  double? _pauseAnchorLat;
  double? _pauseAnchorLng;
  int _recoveryFixesLeft = 0;
  double _smoothedSpeedKmh = 0;
  DateTime? _lastPhoneMotionAt;
  bool _phoneMoving = false;
  /// Início da sessão (relógio de parede) — Tempo nunca trava por Timer atrasado.
  DateTime? _runStartedAt;
  DateTime? _pauseStartedAt;
  int _closedPausedSec = 0;

  final List<TrackedPoint> _accepted = [];
  final List<TrackedPoint> _buffer = [];
  final List<KmSplit> _splits = [];

  List<TrackedPoint> get acceptedPoints => List.unmodifiable(_accepted);
  List<KmSplit> get splits => List.unmodifiable(_splits);
  TrackedPoint? get lastAccepted => _lastAccepted;
  bool get isPaused => manualPaused || autoPaused;
  int get pausedMs => pausedSec * 1000;

  double? get liveLatitude => _lastRawLat ?? _lastAccepted?.latitude;
  double? get liveLongitude => _lastRawLng ?? _lastAccepted?.longitude;

  double get displaySpeedKmh => _smoothedSpeedKmh;

  /// Distância ao vivo: aceita + trecho até o fix atual (estilo Google Maps).
  double get liveDistanceMeters {
    var d = distanceMeters + estimatedGapMeters;
    if (isPaused) return d;
    final last = _lastAccepted;
    if (last == null || _lastRawLat == null || _lastRawLng == null) return d;
    final tip = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      _lastRawLat!,
      _lastRawLng!,
    );
    // Só soma o tip se for deslocamento real (não jitter).
    if (tip >= 0.5 && tip < maxJumpMeters) {
      d += tip;
    }
    return d;
  }

  bool get isStationary => _smoothedSpeedKmh < pauseBelowKmh && !_phoneMoving;

  bool get hasGpsSignal {
    final last = lastRawFixAt ?? lastFixAt;
    if (last == null) return false;
    return DateTime.now().difference(last) <= gpsLossTimeout;
  }

  Duration? get timeSinceLastFix {
    final last = lastRawFixAt ?? lastFixAt;
    if (last == null) return null;
    return DateTime.now().difference(last);
  }

  double? get averagePaceSecPerKm {
    if (distanceMeters < 20 || movingElapsedSec <= 0) return null;
    return movingElapsedSec / (distanceMeters / 1000.0);
  }

  double? get currentPaceSecPerKm {
    if (_smoothedSpeedKmh < 1.0) return null;
    return 3600.0 / _smoothedSpeedKmh;
  }

  static String formatPace(double? secPerKm) {
    if (secPerKm == null || secPerKm.isNaN || secPerKm.isInfinite) {
      return '--';
    }
    if (secPerKm > 60 * 30) return '--';
    final total = secPerKm.round();
    final m = total ~/ 60;
    final s = total % 60;
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  void notePhoneAcceleration(double ax, double ay, double az, {DateTime? now}) {
    final mag = math.sqrt(ax * ax + ay * ay + az * az);
    final jerk = (mag - 9.81).abs();
    final at = now ?? DateTime.now();
    if (jerk >= 1.15 || mag >= 11.0) {
      _lastPhoneMotionAt = at;
      _phoneMoving = true;
    } else if (_lastPhoneMotionAt != null &&
        at.difference(_lastPhoneMotionAt!) > const Duration(seconds: 2)) {
      _phoneMoving = false;
    }
  }

  void markRunStarted(DateTime at) {
    _runStartedAt = at;
    _closedPausedSec = pausedSec;
    if (isPaused) {
      _pauseStartedAt = at;
    }
  }

  void restore({
    required List<TrackedPoint> points,
    required double distanceMeters,
    double estimatedGapMeters = 0,
    double elevationGainMeters = 0,
    int movingElapsedSec = 0,
    int pausedSec = 0,
    int pauseCount = 0,
    List<KmSplit> splits = const [],
    bool autoPaused = false,
    bool manualPaused = false,
    DateTime? runStartedAt,
  }) {
    reset();
    _accepted.addAll(points);
    _buffer.addAll(
      points.length > bufferSize
          ? points.sublist(points.length - bufferSize)
          : points,
    );
    _splits.addAll(splits);
    this.distanceMeters = distanceMeters;
    this.estimatedGapMeters = estimatedGapMeters;
    this.elevationGainMeters = elevationGainMeters;
    this.movingElapsedSec = movingElapsedSec;
    this.pausedSec = pausedSec;
    this.pauseCount = pauseCount;
    this.autoPaused = enableAutoPause && autoPaused;
    this.manualPaused = manualPaused;
    _closedPausedSec = pausedSec;
    _runStartedAt = runStartedAt;
    _distanceAtLastSplit = (distanceMeters / 1000).floor() * 1000.0;
    _movingSecAtLastSplit = movingElapsedSec;
    _elevAtLastSplit = elevationGainMeters;
    _pauseTickAt = isPaused ? DateTime.now() : null;
    _pauseStartedAt = isPaused ? DateTime.now() : null;
    _recoveryFixesLeft = 3;
    if (points.isNotEmpty) {
      final last = points.last;
      _lastAccepted = last;
      lastFixAt = last.recordedAt;
      lastRawFixAt = last.recordedAt;
      sequenceNum = last.sequenceNum + 1;
      lastValidSpeedKmh = last.speedKmh;
      _lastAltitude = last.altitudeMeters;
      currentActivity = last.activity ?? MotionActivity.stopped;
      _smoothedSpeedKmh = last.speedKmh ?? 0;
      _lastRawLat = last.latitude;
      _lastRawLng = last.longitude;
      _lastRawAt = last.recordedAt;
      if (this.autoPaused || manualPaused) {
        _pauseAnchorLat = last.latitude;
        _pauseAnchorLng = last.longitude;
      }
    }
  }

  void reset() {
    distanceMeters = 0;
    estimatedGapMeters = 0;
    elevationGainMeters = 0;
    sequenceNum = 0;
    movingElapsedSec = 0;
    pausedSec = 0;
    pauseCount = 0;
    lastFixAt = null;
    lastRawFixAt = null;
    lastValidSpeedKmh = null;
    autoPaused = false;
    manualPaused = false;
    currentActivity = MotionActivity.stopped;
    _lastAccepted = null;
    _stillSince = null;
    _lastMovingTickAt = null;
    _pauseTickAt = null;
    _distanceAtLastSplit = 0;
    _movingSecAtLastSplit = 0;
    _elevAtLastSplit = 0;
    _lastAltitude = null;
    _lastRawLat = null;
    _lastRawLng = null;
    _lastRawAt = null;
    _pauseAnchorLat = null;
    _pauseAnchorLng = null;
    _recoveryFixesLeft = 0;
    _smoothedSpeedKmh = 0;
    _lastPhoneMotionAt = null;
    _phoneMoving = false;
    _runStartedAt = null;
    _pauseStartedAt = null;
    _closedPausedSec = 0;
    _accepted.clear();
    _buffer.clear();
    _splits.clear();
  }

  void markForegroundRecovery() {
    _recoveryFixesLeft = 5;
  }

  void setManualPaused(bool paused) {
    if (paused == manualPaused) return;
    final now = DateTime.now();
    if (paused) {
      manualPaused = true;
      pauseCount++;
      currentActivity = MotionActivity.stopped;
      _lastMovingTickAt = null;
      _pauseTickAt = now;
      _pauseStartedAt = now;
      _pauseAnchorLat = _lastRawLat ?? _lastAccepted?.latitude;
      _pauseAnchorLng = _lastRawLng ?? _lastAccepted?.longitude;
    } else {
      if (_pauseStartedAt != null) {
        _closedPausedSec += now.difference(_pauseStartedAt!).inSeconds;
        _pauseStartedAt = null;
      }
      manualPaused = false;
      autoPaused = false;
      _stillSince = null;
      _pauseTickAt = null;
      _pauseAnchorLat = null;
      _pauseAnchorLng = null;
      _lastMovingTickAt = now;
      _recoveryFixesLeft = 3;
      pausedSec = _closedPausedSec;
    }
  }

  void toggleManualPause() => setManualPaused(!manualPaused);

  void _pushSpeed(double sampleKmh) {
    sampleKmh = sampleKmh.clamp(0, maxSpeedKmh);
    if (sampleKmh <= 0) {
      // Decai lento — entre fixes de 0,5s não zera a UI.
      _smoothedSpeedKmh *= 0.92;
      if (_smoothedSpeedKmh < 0.4) _smoothedSpeedKmh = 0;
      return;
    }
    // Sobe quase na hora (tempo real).
    if (_smoothedSpeedKmh < 2.0) {
      _smoothedSpeedKmh = sampleKmh;
    } else if (sampleKmh > _smoothedSpeedKmh) {
      _smoothedSpeedKmh = _smoothedSpeedKmh * 0.15 + sampleKmh * 0.85;
    } else {
      _smoothedSpeedKmh = _smoothedSpeedKmh * 0.45 + sampleKmh * 0.55;
    }
  }

  MotionActivity _classify(double speedKmh) {
    if (currentActivity == MotionActivity.run) {
      if (speedKmh < pauseBelowKmh) {
        currentActivity = MotionActivity.stopped;
      } else if (speedKmh < runExitKmh) {
        currentActivity = MotionActivity.walk;
      }
    } else if (currentActivity == MotionActivity.walk) {
      if (speedKmh < pauseBelowKmh) {
        currentActivity = MotionActivity.stopped;
      } else if (speedKmh >= runEnterKmh) {
        currentActivity = MotionActivity.run;
      }
    } else {
      if (speedKmh >= runEnterKmh) {
        currentActivity = MotionActivity.run;
      } else if (speedKmh >= pauseBelowKmh) {
        currentActivity = MotionActivity.walk;
      }
    }
    return currentActivity;
  }

  double _displacementFromPauseAnchor(double lat, double lng) {
    if (_pauseAnchorLat == null || _pauseAnchorLng == null) return 0;
    return Geolocator.distanceBetween(
      _pauseAnchorLat!,
      _pauseAnchorLng!,
      lat,
      lng,
    );
  }

  void _enterAutoPause(double? lat, double? lng) {
    if (!enableAutoPause || autoPaused) return;
    autoPaused = true;
    pauseCount++;
    currentActivity = MotionActivity.stopped;
    _lastMovingTickAt = null;
    final now = DateTime.now();
    _pauseTickAt ??= now;
    _pauseStartedAt ??= now;
    _pauseAnchorLat = lat ?? _lastRawLat ?? _lastAccepted?.latitude;
    _pauseAnchorLng = lng ?? _lastRawLng ?? _lastAccepted?.longitude;
  }

  void _exitAutoPause(DateTime now) {
    if (_pauseStartedAt != null) {
      _closedPausedSec += now.difference(_pauseStartedAt!).inSeconds;
      _pauseStartedAt = null;
    }
    autoPaused = false;
    _stillSince = null;
    _pauseTickAt = null;
    _pauseAnchorLat = null;
    _pauseAnchorLng = null;
    _lastMovingTickAt = now;
    _recoveryFixesLeft = 3;
    pausedSec = _closedPausedSec;
  }

  void _updateAutoPause({
    required double lat,
    required double lng,
    required DateTime now,
  }) {
    if (!enableAutoPause || manualPaused) return;

    if (autoPaused) {
      final moved = _displacementFromPauseAnchor(lat, lng);
      final recentMotion = _lastPhoneMotionAt != null &&
          now.difference(_lastPhoneMotionAt!) <= const Duration(seconds: 3);
      if (moved >= resumeDisplacementMeters ||
          _smoothedSpeedKmh >= resumeAboveKmh ||
          (recentMotion && moved >= 2.0)) {
        _exitAutoPause(now);
      }
      return;
    }

    final stillGps = _smoothedSpeedKmh < pauseBelowKmh;
    final stillPhone = !_phoneMoving;
    if (stillGps && stillPhone) {
      _stillSince ??= now;
      if (now.difference(_stillSince!) >= autoPauseAfter) {
        _enterAutoPause(lat, lng);
      }
    } else {
      _stillSince = null;
    }
  }

  /// Tempo em movimento pelo relógio de parede (não depende de Timer.periodic).
  int elapsedMovingSecAt(DateTime now) {
    if (_runStartedAt == null) return movingElapsedSec;
    final total = now.difference(_runStartedAt!).inSeconds;
    var paused = _closedPausedSec;
    if (isPaused && _pauseStartedAt != null) {
      paused += now.difference(_pauseStartedAt!).inSeconds;
    }
    final moving = total - paused;
    return moving < 0 ? 0 : (moving > 86400 * 7 ? 86400 * 7 : moving);
  }

  void tickMovingTime(DateTime now) {
    if (_runStartedAt != null) {
      movingElapsedSec = elapsedMovingSecAt(now);
      if (isPaused && _pauseStartedAt != null) {
        pausedSec =
            _closedPausedSec + now.difference(_pauseStartedAt!).inSeconds;
      } else {
        pausedSec = _closedPausedSec;
      }
      _lastMovingTickAt = isPaused ? null : now;
      _pauseTickAt = isPaused ? now : null;
      return;
    }

    // Fallback legado (testes sem markRunStarted).
    if (isPaused) {
      if (_pauseTickAt != null) {
        final d = now.difference(_pauseTickAt!).inSeconds;
        if (d > 0) {
          pausedSec += d > 600 ? 600 : d;
        }
      }
      _pauseTickAt = now;
      _lastMovingTickAt = null;
      return;
    }
    _pauseTickAt = null;
    if (_lastMovingTickAt != null) {
      final d = now.difference(_lastMovingTickAt!).inSeconds;
      if (d > 0) {
        movingElapsedSec += d > 600 ? 600 : d;
      }
    } else {
      _lastMovingTickAt = now;
      return;
    }
    _lastMovingTickAt = now;
  }

  double _accuracyLimit(DateTime recordedAt) {
    final previous = _lastAccepted;
    final longGap = previous == null ||
        recordedAt.difference(previous.recordedAt) >=
            const Duration(seconds: 20);
    if (autoPaused || _recoveryFixesLeft > 0 || longGap) {
      return relaxedAccuracyMeters;
    }
    return maxAccuracyMeters;
  }

  GpsProcessResult process(Position pos, {DateTime? now}) {
    final recordedAt = now ?? DateTime.now();
    lastRawFixAt = recordedAt;

    final accuracy = pos.accuracy.isNaN ? 25.0 : pos.accuracy;
    final altitude = pos.altitude.isNaN ? null : pos.altitude;
    final chipSpeedKmh =
        pos.speed.isNaN || pos.speed < 0 ? null : pos.speed * 3.6;

    final prevLat = _lastRawLat;
    final prevLng = _lastRawLng;
    final prevAt = _lastRawAt;

    _lastRawLat = pos.latitude;
    _lastRawLng = pos.longitude;
    _lastRawAt = recordedAt;

    // Velocidade: chip do GPS responde rápido; deslocamento confirma.
    double sampleSpeed = 0;
    double step = 0;
    double dt = 0;
    if (prevLat != null && prevLng != null && prevAt != null) {
      dt = recordedAt.difference(prevAt).inMilliseconds / 1000.0;
      if (dt >= 0.2 && dt <= 25) {
        step = Geolocator.distanceBetween(
          prevLat,
          prevLng,
          pos.latitude,
          pos.longitude,
        );
        if (step >= 0.25) {
          sampleSpeed = (step / dt) * 3.6;
        }
      }
    }
    final chip = chipSpeedKmh ?? 0;
    if (sampleSpeed <= 0 && chip >= 0.8) {
      // Chip mentiroso parado: só aceita se houve passo mínimo ou acel. do telefone.
      if (step >= 0.15 || _phoneMoving) {
        sampleSpeed = chip;
      }
    } else if (sampleSpeed > 0 && chip >= 0.8) {
      sampleSpeed = sampleSpeed * 0.45 + chip * 0.55;
    } else if (sampleSpeed <= 0 && _phoneMoving && _smoothedSpeedKmh > 0) {
      sampleSpeed = _smoothedSpeedKmh;
    }
    _pushSpeed(sampleSpeed);

    if (!manualPaused) {
      if (prevAt != null &&
          recordedAt.difference(prevAt) >= const Duration(seconds: 20)) {
        _stillSince = null;
      }
      _updateAutoPause(
        lat: pos.latitude,
        lng: pos.longitude,
        now: recordedAt,
      );
    }

    final accuracyLimit = _accuracyLimit(recordedAt);
    if (accuracy > accuracyLimit) {
      return GpsProcessResult.rejected(
        GpsRejectReason.accuracy,
        activity: currentActivity,
        autoPaused: autoPaused,
        manualPaused: manualPaused,
      );
    }

    final previous = _lastAccepted;
    if (previous != null) {
      final jumpDelta = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      final jumpDt =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;
      if (jumpDt < 12 && jumpDelta > maxJumpMeters) {
        return GpsProcessResult.rejected(
          GpsRejectReason.jump,
          activity: currentActivity,
        );
      }
      if (jumpDt > 0.4 && jumpDt < 12) {
        final implied = (jumpDelta / jumpDt) * 3.6;
        if (implied > maxSpeedKmh) {
          return GpsProcessResult.rejected(
            GpsRejectReason.speed,
            activity: currentActivity,
          );
        }
      }
    }

    lastFixAt = recordedAt;
    if (_recoveryFixesLeft > 0) _recoveryFixesLeft--;

    if (manualPaused) {
      currentActivity = MotionActivity.stopped;
      return GpsProcessResult.rejected(
        GpsRejectReason.manualPaused,
        activity: MotionActivity.stopped,
        manualPaused: true,
        autoPaused: autoPaused,
      );
    }

    if (autoPaused) {
      currentActivity = MotionActivity.stopped;
      return GpsProcessResult.rejected(
        GpsRejectReason.autoPaused,
        activity: MotionActivity.stopped,
        autoPaused: true,
      );
    }

    final activity = _classify(_smoothedSpeedKmh);

    if (previous != null) {
      final delta = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      final dtSec =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;
      final recovering = dtSec >= 20;

      // Aceita pontos densos (~1,5 m) para o mapa seguir a rua, não virar reta.
      if (!recovering && delta < minDistanceMeters) {
        return GpsProcessResult.rejected(
          GpsRejectReason.tooSoon,
          activity: activity,
        );
      }

      if (dtSec >= 20 &&
          lastValidSpeedKmh != null &&
          lastValidSpeedKmh! >= 2.5 &&
          lastValidSpeedKmh! <= maxSpeedKmh) {
        final estimate = (lastValidSpeedKmh! / 3.6) * dtSec;
        final surplus = (estimate - delta).clamp(0.0, estimate * 0.35);
        estimatedGapMeters += surplus;
      }

      if (!recovering && delta >= minDistanceMeters) {
        distanceMeters += delta;
      }

      if (altitude != null && _lastAltitude != null) {
        final elevDelta = altitude - _lastAltitude!;
        if (elevDelta > 1.5 && elevDelta < 25) {
          elevationGainMeters += elevDelta;
        }
      }
    }

    if (_smoothedSpeedKmh >= 1.0) {
      lastValidSpeedKmh = _smoothedSpeedKmh;
    }

    final point = TrackedPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedKmh: _smoothedSpeedKmh,
      accuracyMeters: accuracy,
      altitudeMeters: altitude,
      recordedAt: recordedAt,
      sequenceNum: sequenceNum++,
      activity: activity,
    );

    _lastAccepted = point;
    if (altitude != null) _lastAltitude = altitude;

    _accepted.add(point);
    _buffer.add(point);
    if (_buffer.length > bufferSize) {
      _buffer.removeAt(0);
    }

    KmSplit? newSplit;
    while (distanceMeters - _distanceAtLastSplit >= 1000) {
      final km = (_distanceAtLastSplit / 1000).round() + 1;
      final splitSec = movingElapsedSec - _movingSecAtLastSplit;
      final elevSplit = elevationGainMeters - _elevAtLastSplit;
      newSplit = KmSplit(
        km: km,
        movingSecAtSplit: movingElapsedSec,
        splitSec: splitSec > 0 ? splitSec : 0,
        paceSecPerKm: splitSec > 0 ? splitSec.toDouble() : 0,
        elevationGainMeters: elevSplit < 0 ? 0 : elevSplit,
      );
      _splits.add(newSplit);
      _distanceAtLastSplit += 1000;
      _movingSecAtLastSplit = movingElapsedSec;
      _elevAtLastSplit = elevationGainMeters;
    }

    return GpsProcessResult.accepted(
      point: point,
      deltaMeters: previous == null
          ? 0
          : Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              pos.latitude,
              pos.longitude,
            ),
      activity: activity,
      newSplit: newSplit,
    );
  }

  /// Rota para o mapa: pontos aceitos (sem média que “corta curva” das ruas).
  List<TrackedPoint> smoothedRoute() => List.unmodifiable(_accepted);

  List<Map<String, dynamic>> pointsForSync() =>
      _accepted.map((p) => p.toJson()).toList();
}
