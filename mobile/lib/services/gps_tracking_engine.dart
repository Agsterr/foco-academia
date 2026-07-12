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

/// Tracking estilo apps de corrida (Strava/Garmin):
/// - Kalman 2D suaviza jitter do GPS
/// - Velocidade = deslocamento filtrado / tempo (chip só como apoio)
/// - Auto-pause clássico + acelerômetro (movimento do telefone)
/// - Sem “janela estacionária” que prende em parado
class GpsTrackingEngine {
  GpsTrackingEngine({
    this.maxAccuracyMeters = 40,
    this.relaxedAccuracyMeters = 60,
    this.maxSpeedKmh = 36,
    this.maxJumpMeters = 70,
    this.minDistanceMeters = 2.5,
    this.bufferSize = 40,
    this.smoothWindow = 3,
    this.gpsLossTimeout = const Duration(seconds: 45),
    this.pauseBelowKmh = 1.2,
    this.resumeAboveKmh = 1.8,
    this.resumeDisplacementMeters = 4,
    this.autoPauseAfter = const Duration(seconds: 12),
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

  final _KalmanLatLng _kalman = _KalmanLatLng();
  final List<TrackedPoint> _accepted = [];
  final List<TrackedPoint> _buffer = [];
  final List<KmSplit> _splits = [];

  List<TrackedPoint> get acceptedPoints => List.unmodifiable(_accepted);
  List<KmSplit> get splits => List.unmodifiable(_splits);
  TrackedPoint? get lastAccepted => _lastAccepted;
  bool get isPaused => manualPaused || autoPaused;
  int get pausedMs => pausedSec * 1000;

  double? get liveLatitude =>
      _kalman.hasEstimate ? _kalman.lat : (_lastRawLat ?? _lastAccepted?.latitude);
  double? get liveLongitude =>
      _kalman.hasEstimate ? _kalman.lng : (_lastRawLng ?? _lastAccepted?.longitude);

  double get displaySpeedKmh => _smoothedSpeedKmh;

  /// Mantido por compatibilidade — não usa mais bbox estacionária.
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

  /// Acelerômetro do telefone (estilo Strava): |a| longe de ~9.8 = movimento.
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
    this.autoPaused = autoPaused;
    this.manualPaused = manualPaused;
    _distanceAtLastSplit = (distanceMeters / 1000).floor() * 1000.0;
    _movingSecAtLastSplit = movingElapsedSec;
    _elevAtLastSplit = elevationGainMeters;
    _pauseTickAt = isPaused ? DateTime.now() : null;
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
      _kalman.reset(last.latitude, last.longitude);
      if (autoPaused || manualPaused) {
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
    _kalman.clear();
    _accepted.clear();
    _buffer.clear();
    _splits.clear();
  }

  void markForegroundRecovery() {
    _recoveryFixesLeft = 5;
  }

  void setManualPaused(bool paused) {
    if (paused == manualPaused) return;
    if (paused) {
      manualPaused = true;
      pauseCount++;
      currentActivity = MotionActivity.stopped;
      _lastMovingTickAt = null;
      _pauseTickAt = DateTime.now();
      _pauseAnchorLat = _lastRawLat ?? _lastAccepted?.latitude;
      _pauseAnchorLng = _lastRawLng ?? _lastAccepted?.longitude;
    } else {
      manualPaused = false;
      autoPaused = false;
      _stillSince = null;
      _pauseTickAt = null;
      _pauseAnchorLat = null;
      _pauseAnchorLng = null;
      _lastMovingTickAt = DateTime.now();
      _recoveryFixesLeft = 3;
    }
  }

  void toggleManualPause() => setManualPaused(!manualPaused);

  void _pushSpeed(double sampleKmh) {
    sampleKmh = sampleKmh.clamp(0, maxSpeedKmh);
    if (_smoothedSpeedKmh <= 0) {
      _smoothedSpeedKmh = sampleKmh;
    } else if (sampleKmh > _smoothedSpeedKmh) {
      // Sobe rápido (retomar caminhada/corrida).
      _smoothedSpeedKmh = _smoothedSpeedKmh * 0.4 + sampleKmh * 0.6;
    } else {
      // Desce mais lento (anti-flicker).
      _smoothedSpeedKmh = _smoothedSpeedKmh * 0.75 + sampleKmh * 0.25;
    }
    if (_smoothedSpeedKmh < 0.35) _smoothedSpeedKmh = 0;
  }

  MotionActivity _classify(double speedKmh) {
    // Bandas largas + histerese (padrão apps de corrida).
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
    if (autoPaused) return;
    autoPaused = true;
    pauseCount++;
    currentActivity = MotionActivity.stopped;
    _lastMovingTickAt = null;
    _pauseTickAt ??= DateTime.now();
    _pauseAnchorLat = lat ?? _lastRawLat ?? _lastAccepted?.latitude;
    _pauseAnchorLng = lng ?? _lastRawLng ?? _lastAccepted?.longitude;
  }

  void _exitAutoPause(DateTime now) {
    autoPaused = false;
    _stillSince = null;
    _pauseTickAt = null;
    _pauseAnchorLat = null;
    _pauseAnchorLng = null;
    _lastMovingTickAt = now;
    _recoveryFixesLeft = 3;
  }

  void _updateAutoPause({
    required double lat,
    required double lng,
    required DateTime now,
  }) {
    if (manualPaused) return;

    if (autoPaused) {
      final moved = _displacementFromPauseAnchor(lat, lng);
      final recentMotion = _lastPhoneMotionAt != null &&
          now.difference(_lastPhoneMotionAt!) <= const Duration(seconds: 3);
      if (moved >= resumeDisplacementMeters ||
          _smoothedSpeedKmh >= resumeAboveKmh ||
          (recentMotion && _smoothedSpeedKmh >= pauseBelowKmh) ||
          (recentMotion && moved >= 2.0)) {
        _exitAutoPause(now);
      }
      return;
    }

    // Strava-like: só pausa se GPS lento E telefone sem movimento.
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

  void tickMovingTime(DateTime now) {
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

    _lastRawLat = pos.latitude;
    _lastRawLng = pos.longitude;
    _lastRawAt = recordedAt;

    // 1) Kalman suaviza posição (ruído ∝ accuracy²).
    final filtered = _kalman.update(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyMeters: accuracy,
      at: recordedAt,
    );

    // 2) Velocidade pelo deslocamento filtrado (nunca confia no chip parado).
    final step = filtered.stepMeters;
    final dt = filtered.dtSec;
    double sampleSpeed = 0;
    if (dt >= 0.4 && dt <= 20) {
      if (step < math.max(0.8, accuracy * 0.15)) {
        // Drift / jitter: velocidade 0 (chip mentiroso ignorado).
        sampleSpeed = 0;
      } else {
        sampleSpeed = (step / dt) * 3.6;
        // Chip só entra se concordar aproximadamente com o deslocamento.
        if (chipSpeedKmh != null &&
            chipSpeedKmh > 0 &&
            (chipSpeedKmh - sampleSpeed).abs() < 4.0) {
          sampleSpeed = sampleSpeed * 0.7 + chipSpeedKmh * 0.3;
        }
      }
    }
    _pushSpeed(sampleSpeed);

    if (!manualPaused) {
      // Após gap longo limpa “parado” velho — evita auto-pause fantasma.
      if (filtered.dtSec >= 20) {
        _stillSince = null;
      }
      _updateAutoPause(
        lat: filtered.lat,
        lng: filtered.lng,
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
        filtered.lat,
        filtered.lng,
      );
      final jumpDt =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;
      if (jumpDt < 15 && jumpDelta > maxJumpMeters) {
        return GpsProcessResult.rejected(
          GpsRejectReason.jump,
          activity: currentActivity,
        );
      }
      if (jumpDt > 0.3 && jumpDt < 15) {
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
        filtered.lat,
        filtered.lng,
      );
      final dtSec =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;
      final recovering = dtSec >= 20;

      // Anti-drift: só soma se andou de verdade (acima do min + fração da accuracy).
      final minStep = math.max(minDistanceMeters, accuracy * 0.25);
      if (!recovering && delta < minStep) {
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
        final surplus = (estimate - delta).clamp(0.0, estimate * 0.4);
        estimatedGapMeters += surplus;
      }

      if (!recovering && delta >= minStep) {
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
      latitude: filtered.lat,
      longitude: filtered.lng,
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
              filtered.lat,
              filtered.lng,
            ),
      activity: activity,
      newSplit: newSplit,
    );
  }

  List<TrackedPoint> smoothedRoute() {
    if (_accepted.length < 3) return List.unmodifiable(_accepted);
    final window = smoothWindow.clamp(3, 9);
    final half = window ~/ 2;
    final out = <TrackedPoint>[];

    for (var i = 0; i < _accepted.length; i++) {
      final start = (i - half).clamp(0, _accepted.length - 1);
      final end = (i + half).clamp(0, _accepted.length - 1);
      var lat = 0.0;
      var lng = 0.0;
      var n = 0;
      for (var j = start; j <= end; j++) {
        lat += _accepted[j].latitude;
        lng += _accepted[j].longitude;
        n++;
      }
      final src = _accepted[i];
      out.add(
        TrackedPoint(
          latitude: lat / n,
          longitude: lng / n,
          speedKmh: src.speedKmh,
          accuracyMeters: src.accuracyMeters,
          altitudeMeters: src.altitudeMeters,
          recordedAt: src.recordedAt,
          sequenceNum: src.sequenceNum,
          activity: src.activity,
        ),
      );
    }
    return out;
  }

  List<Map<String, dynamic>> pointsForSync() =>
      _accepted.map((p) => p.toJson()).toList();
}

class _KalmanUpdate {
  const _KalmanUpdate({
    required this.lat,
    required this.lng,
    required this.stepMeters,
    required this.dtSec,
  });
  final double lat;
  final double lng;
  final double stepMeters;
  final double dtSec;
}

/// Filtro de Kalman 2D (posição constante + ruído de processo).
/// Measurement noise R = accuracy² — padrão usado em trackers GPS.
class _KalmanLatLng {
  double? _lat;
  double? _lng;
  double _pLat = 1;
  double _pLng = 1;
  DateTime? _at;
  bool get hasEstimate => _lat != null && _lng != null;
  double get lat => _lat!;
  double get lng => _lng!;

  void clear() {
    _lat = null;
    _lng = null;
    _pLat = 1;
    _pLng = 1;
    _at = null;
  }

  void reset(double lat, double lng) {
    _lat = lat;
    _lng = lng;
    _pLat = 1;
    _pLng = 1;
    _at = null;
  }

  _KalmanUpdate update({
    required double lat,
    required double lng,
    required double accuracyMeters,
    required DateTime at,
  }) {
    final r = math.max(1.0, accuracyMeters * accuracyMeters);
    // Process noise ~ aceleração humana tipica (caminhada/corrida).
    const qBase = 3.0; // m²/s (escala em graus via conversão abaixo)

    if (_lat == null || _lng == null || _at == null) {
      _lat = lat;
      _lng = lng;
      _pLat = r;
      _pLng = r;
      _at = at;
      return _KalmanUpdate(lat: lat, lng: lng, stepMeters: 0, dtSec: 0);
    }

    final dt = at.difference(_at!).inMilliseconds / 1000.0;

    // Gap longo (tela apagada): reancora sem interpolar teleporte.
    if (dt >= 20) {
      _lat = lat;
      _lng = lng;
      _pLat = r;
      _pLng = r;
      _at = at;
      return _KalmanUpdate(lat: lat, lng: lng, stepMeters: 0, dtSec: dt);
    }

    final dtClamped = dt.clamp(0.05, 30.0);
    final q = qBase * dtClamped;

    // Converte metros² → graus² aproximados na latitude atual.
    final metersPerDegLat = 110540.0;
    final metersPerDegLng = 111320.0 * math.cos(_lat! * math.pi / 180);
    final qLat = q / (metersPerDegLat * metersPerDegLat);
    final qLng = q / (metersPerDegLng * metersPerDegLng);
    final rLat = r / (metersPerDegLat * metersPerDegLat);
    final rLng = r / (metersPerDegLng * metersPerDegLng);

    _pLat += qLat;
    _pLng += qLng;

    final kLat = _pLat / (_pLat + rLat);
    final kLng = _pLng / (_pLng + rLng);

    final prevLat = _lat!;
    final prevLng = _lng!;
    _lat = _lat! + kLat * (lat - _lat!);
    _lng = _lng! + kLng * (lng - _lng!);
    _pLat = (1 - kLat) * _pLat;
    _pLng = (1 - kLng) * _pLng;
    _at = at;

    final step = Geolocator.distanceBetween(prevLat, prevLng, _lat!, _lng!);
    return _KalmanUpdate(
      lat: _lat!,
      lng: _lng!,
      stepMeters: step,
      dtSec: dt,
    );
  }
}
