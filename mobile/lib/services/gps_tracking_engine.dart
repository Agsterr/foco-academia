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

/// Filtra pontos GPS, calcula distância, pace, splits, elevação e auto-pause.
class GpsTrackingEngine {
  GpsTrackingEngine({
    this.maxAccuracyMeters = 30,
    this.maxSpeedKmh = 40,
    this.maxJumpMeters = 100,
    this.minDistanceMeters = 5,
    this.bufferSize = 20,
    this.smoothWindow = 5,
    this.gpsLossTimeout = const Duration(seconds: 20),
    this.pauseBelowKmh = 1.6,
    this.resumeAboveKmh = 2.4,
    this.autoPauseAfter = const Duration(seconds: 8),
    this.walkBelowKmh = 7.0,
  });

  final double maxAccuracyMeters;
  final double maxSpeedKmh;
  final double maxJumpMeters;
  final double minDistanceMeters;
  final int bufferSize;
  final int smoothWindow;
  final Duration gpsLossTimeout;
  final double pauseBelowKmh;
  final double resumeAboveKmh;
  final Duration autoPauseAfter;
  final double walkBelowKmh;

  double distanceMeters = 0;
  double estimatedGapMeters = 0;
  double elevationGainMeters = 0;
  int sequenceNum = 0;
  int movingElapsedSec = 0;
  int pausedSec = 0;
  int pauseCount = 0;
  DateTime? lastFixAt;
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

  final List<TrackedPoint> _accepted = [];
  final List<TrackedPoint> _buffer = [];
  final List<KmSplit> _splits = [];
  final List<double> _recentSpeeds = [];

  List<TrackedPoint> get acceptedPoints => List.unmodifiable(_accepted);
  List<KmSplit> get splits => List.unmodifiable(_splits);
  TrackedPoint? get lastAccepted => _lastAccepted;
  bool get isPaused => manualPaused || autoPaused;
  int get pausedMs => pausedSec * 1000;

  bool get hasGpsSignal {
    final last = lastFixAt;
    if (last == null) return false;
    return DateTime.now().difference(last) <= gpsLossTimeout;
  }

  Duration? get timeSinceLastFix {
    final last = lastFixAt;
    if (last == null) return null;
    return DateTime.now().difference(last);
  }

  /// Ritmo médio (segundos por km) com base no tempo em movimento.
  double? get averagePaceSecPerKm {
    if (distanceMeters < 20 || movingElapsedSec <= 0) return null;
    return movingElapsedSec / (distanceMeters / 1000.0);
  }

  /// Ritmo atual a partir das velocidades recentes (segundos por km).
  double? get currentPaceSecPerKm {
    if (_recentSpeeds.isEmpty) return null;
    final avg =
        _recentSpeeds.reduce((a, b) => a + b) / _recentSpeeds.length;
    if (avg < 0.8) return null;
    return 3600.0 / avg;
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
    _accepted
      ..clear()
      ..addAll(points);
    _buffer
      ..clear()
      ..addAll(points.length > bufferSize
          ? points.sublist(points.length - bufferSize)
          : points);
    _splits
      ..clear()
      ..addAll(splits);
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
    _stillSince = null;
    _lastMovingTickAt = null;
    _pauseTickAt = isPaused ? DateTime.now() : null;
    _recentSpeeds.clear();
    if (points.isNotEmpty) {
      _lastAccepted = points.last;
      lastFixAt = points.last.recordedAt;
      sequenceNum = points.last.sequenceNum + 1;
      lastValidSpeedKmh = points.last.speedKmh;
      _lastAltitude = points.last.altitudeMeters;
      currentActivity = points.last.activity ?? MotionActivity.stopped;
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
    _accepted.clear();
    _buffer.clear();
    _splits.clear();
    _recentSpeeds.clear();
  }

  /// Pausa ou retoma manualmente (botão do aluno).
  void setManualPaused(bool paused) {
    if (paused == manualPaused) return;
    if (paused) {
      manualPaused = true;
      pauseCount++;
      currentActivity = MotionActivity.stopped;
      _lastMovingTickAt = null;
      _pauseTickAt = DateTime.now();
    } else {
      manualPaused = false;
      autoPaused = false;
      _stillSince = null;
      _pauseTickAt = null;
      _lastMovingTickAt = DateTime.now();
    }
  }

  void toggleManualPause() => setManualPaused(!manualPaused);

  MotionActivity _classify(double? speedKmh) {
    if (speedKmh == null || speedKmh < pauseBelowKmh) {
      return MotionActivity.stopped;
    }
    if (speedKmh < walkBelowKmh) return MotionActivity.walk;
    return MotionActivity.run;
  }

  void _enterAutoPause() {
    if (autoPaused) return;
    autoPaused = true;
    pauseCount++;
    currentActivity = MotionActivity.stopped;
    _lastMovingTickAt = null;
    _pauseTickAt ??= DateTime.now();
  }

  void _updateAutoPause(double? speedKmh, DateTime now) {
    // Com pausa manual, o aluno controla; GPS não retoma sozinho.
    if (manualPaused) return;

    final speed = speedKmh ?? 0;
    if (autoPaused) {
      if (speed >= resumeAboveKmh) {
        autoPaused = false;
        _stillSince = null;
        _pauseTickAt = null;
        _lastMovingTickAt = now;
      }
      return;
    }
    if (speed < pauseBelowKmh) {
      _stillSince ??= now;
      if (now.difference(_stillSince!) >= autoPauseAfter) {
        _enterAutoPause();
      }
    } else {
      _stillSince = null;
    }
  }

  void tickMovingTime(DateTime now) {
    if (isPaused) {
      if (_pauseTickAt != null) {
        final d = now.difference(_pauseTickAt!).inSeconds;
        if (d > 0 && d < 5) {
          pausedSec += d;
        }
      }
      _pauseTickAt = now;
      _lastMovingTickAt = null;
      return;
    }
    _pauseTickAt = null;
    if (_lastMovingTickAt != null) {
      final d = now.difference(_lastMovingTickAt!).inSeconds;
      if (d > 0 && d < 5) {
        movingElapsedSec += d;
      }
    }
    _lastMovingTickAt = now;
  }

  GpsProcessResult process(Position pos, {DateTime? now}) {
    final recordedAt = now ?? DateTime.now();
    final accuracy = pos.accuracy;
    final speedKmh =
        pos.speed.isNaN || pos.speed < 0 ? null : pos.speed * 3.6;
    final altitude =
        pos.altitude.isNaN ? null : pos.altitude;

    if (!accuracy.isNaN && accuracy > maxAccuracyMeters) {
      return GpsProcessResult.rejected(
        GpsRejectReason.accuracy,
        activity: currentActivity,
        autoPaused: autoPaused,
        manualPaused: manualPaused,
      );
    }

    if (speedKmh != null && speedKmh > maxSpeedKmh) {
      return GpsProcessResult.rejected(
        GpsRejectReason.speed,
        activity: currentActivity,
        autoPaused: autoPaused,
        manualPaused: manualPaused,
      );
    }

    lastFixAt = recordedAt;

    if (manualPaused) {
      currentActivity = MotionActivity.stopped;
      return GpsProcessResult.rejected(
        GpsRejectReason.manualPaused,
        activity: MotionActivity.stopped,
        manualPaused: true,
        autoPaused: autoPaused,
      );
    }

    _updateAutoPause(speedKmh, recordedAt);

    if (autoPaused) {
      currentActivity = MotionActivity.stopped;
      return GpsProcessResult.rejected(
        GpsRejectReason.autoPaused,
        activity: MotionActivity.stopped,
        autoPaused: true,
      );
    }

    final activity = _classify(speedKmh);
    currentActivity = activity;

    final previous = _lastAccepted;
    if (previous != null) {
      final delta = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      final dtSec =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;

      if (delta > maxJumpMeters && dtSec < 15) {
        return GpsProcessResult.rejected(
          GpsRejectReason.jump,
          activity: activity,
        );
      }

      if (dtSec > 0.2) {
        final impliedKmh = (delta / dtSec) * 3.6;
        if (impliedKmh > maxSpeedKmh) {
          return GpsProcessResult.rejected(
            GpsRejectReason.speed,
            activity: activity,
          );
        }
      }

      if (delta < minDistanceMeters) {
        return GpsProcessResult.rejected(
          GpsRejectReason.tooSoon,
          activity: activity,
        );
      }

      if (dtSec >= gpsLossTimeout.inSeconds &&
          lastValidSpeedKmh != null &&
          lastValidSpeedKmh! > 0.5 &&
          lastValidSpeedKmh! <= maxSpeedKmh) {
        final estimate = (lastValidSpeedKmh! / 3.6) * dtSec;
        final surplus = (estimate - delta).clamp(0.0, estimate);
        estimatedGapMeters += surplus;
      }

      distanceMeters += delta;

      if (altitude != null && _lastAltitude != null) {
        final elevDelta = altitude - _lastAltitude!;
        // Filtra ruído de altitude GPS.
        if (elevDelta > 1.5 && elevDelta < 30) {
          elevationGainMeters += elevDelta;
        }
      }
    }

    if (speedKmh != null && speedKmh >= 0.5) {
      lastValidSpeedKmh = speedKmh;
      _recentSpeeds.add(speedKmh);
      if (_recentSpeeds.length > 8) _recentSpeeds.removeAt(0);
    }

    final point = TrackedPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedKmh: speedKmh,
      accuracyMeters: accuracy.isNaN ? null : accuracy,
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
