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
    this.maxAccuracyMeters = 35,
    this.relaxedAccuracyMeters = 55,
    this.maxSpeedKmh = 35,
    this.maxJumpMeters = 80,
    this.minDistanceMeters = 2.0,
    this.bufferSize = 40,
    this.smoothWindow = 3,
    this.gpsLossTimeout = const Duration(seconds: 45),
    this.pauseBelowKmh = 1.0,
    this.resumeAboveKmh = 1.6,
    this.resumeDisplacementMeters = 5,
    this.autoPauseAfter = const Duration(seconds: 20),
    this.walkBelowKmh = 7.5,
    this.runEnterKmh = 8.5,
    this.runExitKmh = 6.5,
    this.stationaryRadiusMeters = 4.0,
    this.stationaryWindow = const Duration(seconds: 6),
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
  final double walkBelowKmh;
  final double runEnterKmh;
  final double runExitKmh;
  /// Se nos últimos N segundos o GPS ficou dentro deste raio → parado (anti-drift).
  final double stationaryRadiusMeters;
  final Duration stationaryWindow;

  double distanceMeters = 0;
  double estimatedGapMeters = 0;
  double elevationGainMeters = 0;
  int sequenceNum = 0;
  int movingElapsedSec = 0;
  int pausedSec = 0;
  int pauseCount = 0;
  /// Último fix com qualidade suficiente para a rota.
  DateTime? lastFixAt;
  /// Qualquer callback do GPS (mesmo rejeitado) — usado no "sem sinal".
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
  MotionActivity _pendingActivity = MotionActivity.stopped;
  int _pendingActivityHits = 0;
  final List<_RawSample> _recentRaw = [];

  final List<TrackedPoint> _accepted = [];
  final List<TrackedPoint> _buffer = [];
  final List<KmSplit> _splits = [];
  final List<double> _recentSpeeds = [];

  List<TrackedPoint> get acceptedPoints => List.unmodifiable(_accepted);
  List<KmSplit> get splits => List.unmodifiable(_splits);
  TrackedPoint? get lastAccepted => _lastAccepted;
  bool get isPaused => manualPaused || autoPaused;
  int get pausedMs => pausedSec * 1000;

  /// Posição ao vivo (último fix recebido) — para o ponto azul no mapa.
  double? get liveLatitude => _lastRawLat ?? _lastAccepted?.latitude;
  double? get liveLongitude => _lastRawLng ?? _lastAccepted?.longitude;

  /// Velocidade filtrada para UI (não usa picos falsos do GPS parado).
  double get displaySpeedKmh => _smoothedSpeedKmh;

  bool get isStationary => _computeStationary(DateTime.now());

  /// Há sinal se o stream ainda entrega fixes (mesmo com precisão ruim).
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

  /// Ritmo médio (segundos por km) com base no tempo em movimento.
  double? get averagePaceSecPerKm {
    if (distanceMeters < 20 || movingElapsedSec <= 0) return null;
    return movingElapsedSec / (distanceMeters / 1000.0);
  }

  /// Ritmo atual a partir das velocidades filtradas (segundos por km).
  double? get currentPaceSecPerKm {
    if (_smoothedSpeedKmh < 0.8) return null;
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
    _lastRawLat = null;
    _lastRawLng = null;
    _lastRawAt = null;
    _pauseAnchorLat = null;
    _pauseAnchorLng = null;
    _recoveryFixesLeft = 3;
    _smoothedSpeedKmh = 0;
    _pendingActivity = MotionActivity.stopped;
    _pendingActivityHits = 0;
    _recentRaw.clear();
    if (points.isNotEmpty) {
      _lastAccepted = points.last;
      lastFixAt = points.last.recordedAt;
      lastRawFixAt = points.last.recordedAt;
      sequenceNum = points.last.sequenceNum + 1;
      lastValidSpeedKmh = points.last.speedKmh;
      _lastAltitude = points.last.altitudeMeters;
      currentActivity = points.last.activity ?? MotionActivity.stopped;
      _lastRawLat = points.last.latitude;
      _lastRawLng = points.last.longitude;
      _lastRawAt = points.last.recordedAt;
      if (autoPaused || manualPaused) {
        _pauseAnchorLat = points.last.latitude;
        _pauseAnchorLng = points.last.longitude;
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
    _pendingActivity = MotionActivity.stopped;
    _pendingActivityHits = 0;
    _recentRaw.clear();
    _accepted.clear();
    _buffer.clear();
    _splits.clear();
    _recentSpeeds.clear();
  }

  /// Chamado ao voltar do background / tela apagada.
  void markForegroundRecovery() {
    _recoveryFixesLeft = 5;
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

  bool _computeStationary(DateTime now) {
    _recentRaw.removeWhere(
      (s) => now.difference(s.at) > stationaryWindow,
    );
    if (_recentRaw.length < 3) return false;
    var minLat = _recentRaw.first.lat;
    var maxLat = minLat;
    var minLng = _recentRaw.first.lng;
    var maxLng = minLng;
    for (final s in _recentRaw) {
      if (s.lat < minLat) minLat = s.lat;
      if (s.lat > maxLat) maxLat = s.lat;
      if (s.lng < minLng) minLng = s.lng;
      if (s.lng > maxLng) maxLng = s.lng;
    }
    final span = Geolocator.distanceBetween(minLat, minLng, maxLat, maxLng);
    return span <= stationaryRadiusMeters;
  }

  /// Velocidade conservadora: GPS reportado mente parado; prioriza deslocamento.
  double _blendSpeed({
    required double? reported,
    required double? implied,
    required bool stationary,
  }) {
    if (stationary) return 0;
    final r = reported ?? 0;
    final i = implied ?? 0;
    if (r <= 0 && i <= 0) return 0;
    if (r <= 0) return i;
    if (i <= 0) return r;
    // Chip muito acima do deslocamento real → confia no deslocamento.
    if (r > i + 2.5) return i;
    return (r * 0.4) + (i * 0.6);
  }

  void _pushSmoothedSpeed(double sample) {
    // EMA: mais peso no histórico para reduzir picos.
    _smoothedSpeedKmh = _smoothedSpeedKmh <= 0
        ? sample
        : (_smoothedSpeedKmh * 0.65) + (sample * 0.35);
    if (_smoothedSpeedKmh < 0.3) _smoothedSpeedKmh = 0;
  }

  MotionActivity _classifyWithHysteresis(double speedKmh) {
    MotionActivity target;
    if (speedKmh < pauseBelowKmh) {
      target = MotionActivity.stopped;
    } else if (currentActivity == MotionActivity.run) {
      target = speedKmh < runExitKmh ? MotionActivity.walk : MotionActivity.run;
    } else if (speedKmh >= runEnterKmh) {
      target = MotionActivity.run;
    } else {
      target = MotionActivity.walk;
    }

    if (target == currentActivity) {
      _pendingActivity = target;
      _pendingActivityHits = 0;
      return currentActivity;
    }
    if (target == _pendingActivity) {
      _pendingActivityHits++;
    } else {
      _pendingActivity = target;
      _pendingActivityHits = 1;
    }
    // Exige 3 leituras iguais antes de mudar (exceto parado imediato se bem parado).
    final need = target == MotionActivity.stopped ? 2 : 3;
    if (_pendingActivityHits >= need) {
      currentActivity = target;
      _pendingActivityHits = 0;
    }
    return currentActivity;
  }

  double? _impliedSpeedKmh(double lat, double lng, DateTime now) {
    if (_lastRawLat == null || _lastRawLng == null || _lastRawAt == null) {
      return null;
    }
    final dtSec = now.difference(_lastRawAt!).inMilliseconds / 1000.0;
    if (dtSec < 0.5 || dtSec > 30) return null;
    final delta = Geolocator.distanceBetween(
      _lastRawLat!,
      _lastRawLng!,
      lat,
      lng,
    );
    // Deslocamentos minúsculos = drift, não velocidade.
    if (delta < 1.0) return 0;
    return (delta / dtSec) * 3.6;
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
    _smoothedSpeedKmh = 0;
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

  /// Auto-pause só com velocidade filtrada + janela estacionária (não speed bruto).
  void _updateAutoPause({
    required double smoothedSpeed,
    required bool stationary,
    required double lat,
    required double lng,
    required DateTime now,
  }) {
    if (manualPaused) return;

    if (autoPaused) {
      final moved = _displacementFromPauseAnchor(lat, lng);
      if ((!stationary && smoothedSpeed >= resumeAboveKmh) ||
          moved >= resumeDisplacementMeters) {
        _exitAutoPause(now);
      }
      return;
    }

    if (stationary || smoothedSpeed < pauseBelowKmh) {
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
        // Tela apagada: Timer.periodic atrasa — recupera o gap (até 10 min).
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
      // Primeiro tick após retomar / restaurar: ancora sem pular.
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

    final accuracy = pos.accuracy;
    final reportedSpeed =
        pos.speed.isNaN || pos.speed < 0 ? null : pos.speed * 3.6;
    final altitude = pos.altitude.isNaN ? null : pos.altitude;
    final implied = _impliedSpeedKmh(pos.latitude, pos.longitude, recordedAt);

    _recentRaw.add(
      _RawSample(pos.latitude, pos.longitude, recordedAt),
    );
    final stationary = _computeStationary(recordedAt);
    final blended = _blendSpeed(
      reported: reportedSpeed,
      implied: implied,
      stationary: stationary,
    );
    if (stationary) {
      // Drift parado: zera na hora (EMA sozinho demora e “mostra correndo”).
      _smoothedSpeedKmh = 0;
      currentActivity = MotionActivity.stopped;
      _pendingActivity = MotionActivity.stopped;
      _pendingActivityHits = 0;
    } else {
      _pushSmoothedSpeed(blended);
    }

    if (!manualPaused) {
      _updateAutoPause(
        smoothedSpeed: _smoothedSpeedKmh,
        stationary: stationary,
        lat: pos.latitude,
        lng: pos.longitude,
        now: recordedAt,
      );
    }

    _lastRawLat = pos.latitude;
    _lastRawLng = pos.longitude;
    _lastRawAt = recordedAt;

    final accuracyLimit = _accuracyLimit(recordedAt);
    if (!accuracy.isNaN && accuracy > accuracyLimit) {
      return GpsProcessResult.rejected(
        GpsRejectReason.accuracy,
        activity: currentActivity,
        autoPaused: autoPaused,
        manualPaused: manualPaused,
      );
    }

    // Salto/teleporte antes do gate de velocidade (senão vira "speed").
    final previous = _lastAccepted;
    if (previous != null) {
      final jumpDelta = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        pos.latitude,
        pos.longitude,
      );
      final jumpDtSec =
          recordedAt.difference(previous.recordedAt).inMilliseconds / 1000.0;
      if (jumpDtSec < 20 && jumpDelta > maxJumpMeters) {
        return GpsProcessResult.rejected(
          GpsRejectReason.jump,
          activity: currentActivity,
        );
      }
    }

    if (_smoothedSpeedKmh > maxSpeedKmh) {
      return GpsProcessResult.rejected(
        GpsRejectReason.speed,
        activity: currentActivity,
        autoPaused: autoPaused,
        manualPaused: manualPaused,
      );
    }

    lastFixAt = recordedAt;
    if (_recoveryFixesLeft > 0) _recoveryFixesLeft--;

    if (manualPaused) {
      currentActivity = MotionActivity.stopped;
      _smoothedSpeedKmh = 0;
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

    // Parado de verdade: não alonga a rota com drift do GPS.
    if (stationary) {
      currentActivity = MotionActivity.stopped;
      return GpsProcessResult.rejected(
        GpsRejectReason.tooSoon,
        activity: MotionActivity.stopped,
      );
    }

    final activity = _classifyWithHysteresis(_smoothedSpeedKmh);

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

      if (dtSec > 0.3 && !recovering) {
        final impliedKmh = (delta / dtSec) * 3.6;
        if (impliedKmh > maxSpeedKmh) {
          return GpsProcessResult.rejected(
            GpsRejectReason.speed,
            activity: activity,
          );
        }
      }

      if (delta < minDistanceMeters && !recovering) {
        if (dtSec < 0.8 || delta < 0.8) {
          return GpsProcessResult.rejected(
            GpsRejectReason.tooSoon,
            activity: activity,
          );
        }
      }

      // Não estima gap após tela apagada se estava lento/parado (evita km fantasmas).
      if (dtSec >= 20 &&
          lastValidSpeedKmh != null &&
          lastValidSpeedKmh! >= 2.0 &&
          lastValidSpeedKmh! <= maxSpeedKmh &&
          !stationary) {
        final estimate = (lastValidSpeedKmh! / 3.6) * dtSec;
        final surplus = (estimate - delta).clamp(0.0, estimate * 0.5);
        estimatedGapMeters += surplus;
      }

      if (!recovering && delta >= 0.8) {
        distanceMeters += delta;
      }

      if (altitude != null && _lastAltitude != null) {
        final elevDelta = altitude - _lastAltitude!;
        if (elevDelta > 1.5 && elevDelta < 25) {
          elevationGainMeters += elevDelta;
        }
      }
    }

    if (_smoothedSpeedKmh >= 0.8) {
      lastValidSpeedKmh = _smoothedSpeedKmh;
      _recentSpeeds.add(_smoothedSpeedKmh);
      if (_recentSpeeds.length > 8) _recentSpeeds.removeAt(0);
    }

    final point = TrackedPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedKmh: _smoothedSpeedKmh,
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

class _RawSample {
  const _RawSample(this.lat, this.lng, this.at);
  final double lat;
  final double lng;
  final DateTime at;
}
