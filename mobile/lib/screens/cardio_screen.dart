import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:uuid/uuid.dart';

import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/calorie_estimator.dart';
import '../services/calories_service.dart';
import '../services/cardio_feedback.dart';
import '../services/cardio_service.dart';
import '../services/activity_share_service.dart';
import '../services/gps_config.dart';
import '../services/gps_diagnostic.dart';
import '../services/gps_diagnostic_store.dart';
import '../services/gps_quality_service.dart';
import '../services/gps_service.dart';
import '../services/gps_tracking_engine.dart';
import '../services/health_sync_service.dart';
import '../services/location_permission_helper.dart';
import '../services/map_matching_service.dart';
import '../services/profile_service.dart';
import '../services/run_export_service.dart';
import '../services/sync_service.dart';
import '../services/outdoor_workout_service.dart';
import '../widgets/route_map_view.dart';

class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key, this.autoResume = false});

  /// Quando true (ex.: após reboot), tenta retomar sem perguntar se houver snapshot.
  final bool autoResume;

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> with WidgetsBindingObserver {
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  Timer? _clockTimer;
  Timer? _gpsWatchdog;

  CardioWorkout? _workout;
  CardioSession? _session;
  List<CardioInterval> _intervals = [];
  int _phaseIndex = 0;
  int _phaseRemaining = 0;

  final _engine = GpsTrackingEngine();
  final _mapMatching = MapMatchingService();
  List<LatLng> _matchedRoute = [];
  LatLng? _snappedLive;
  bool _mapMatchBusy = false;
  int _lastMatchedPointCount = 0;
  DateTime? _lastMatchAt;
  double _distance = 0;
  double _estimatedGap = 0;
  int _elapsed = 0;
  bool _running = false;
  bool _loading = true;
  bool _finishing = false;
  GpsConfig _gpsConfig = GpsConfig.defaults;
  bool _wasGpsLost = false;
  bool _autoPauseEnabled = false;
  bool _autoPaused = false;
  bool _manualPaused = false;
  String? _error;
  String? _clientSessionId;
  double _weightKg = CalorieEstimator.defaultWeightKg;
  String? _gpsStatus;
  DateTime? _startedAt;
  bool _gpsLost = false;
  int _lastCloudSeq = 0;
  DateTime? _lastCloudBackupAt;
  String? _lastSplitToast;
  DateTime? _lastPersistAt;
  int? _lastPersistElapsedSec;
  int? _lastCloudElapsedSec;

  /// Mapa: rota encaixada nas ruas + ponta ao vivo (snap).
  List<RoutePointView> get _mapRoutePoints {
    final matched = _matchedRoute;
    if (matched.length >= 2) {
      final out = matched
          .map((p) => RoutePointView(latitude: p.latitude, longitude: p.longitude))
          .toList();
      final tip = _snappedLive ??
          (_engine.liveLatitude != null && _engine.liveLongitude != null
              ? LatLng(_engine.liveLatitude!, _engine.liveLongitude!)
              : null);
      if (tip != null) {
        final last = matched.last;
        final d = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          tip.latitude,
          tip.longitude,
        );
        if (d >= 0.5) {
          out.add(RoutePointView(latitude: tip.latitude, longitude: tip.longitude));
        }
      }
      return out;
    }

    // Fallback: GPS bruto até o primeiro match.
    final raw = _engine.acceptedPoints;
    final lat = _engine.liveLatitude;
    final lng = _engine.liveLongitude;
    final points = raw
        .map((p) => RoutePointView(latitude: p.latitude, longitude: p.longitude))
        .toList();
    if (_running && lat != null && lng != null) {
      if (points.isEmpty ||
          Geolocator.distanceBetween(
                points.last.latitude,
                points.last.longitude,
                lat,
                lng,
              ) >=
              0.4) {
        points.add(RoutePointView(latitude: lat, longitude: lng));
      }
    }
    return points;
  }

  Future<void> _refreshMapMatching({bool force = false}) async {
    if (!_running || _finishing || _mapMatchBusy) return;
    final accepted = _engine.acceptedPoints;
    if (accepted.length < 3) return;

    final now = DateTime.now();
    final grew = accepted.length - _lastMatchedPointCount >= 4;
    final due = _lastMatchAt == null ||
        now.difference(_lastMatchAt!) >= const Duration(seconds: 4);
    if (!force && !grew && !due) return;

    _mapMatchBusy = true;
    try {
      final pts = accepted
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      final accuracies = accepted
          .map((p) => p.accuracyMeters ?? 25.0)
          .toList();
      final matched = await _mapMatching.matchToRoads(
        pts,
        accuraciesMeters: accuracies,
      );

      LatLng? snapped;
      if (_engine.liveLatitude != null && _engine.liveLongitude != null) {
        snapped = await _mapMatching.snapPoint(
          LatLng(_engine.liveLatitude!, _engine.liveLongitude!),
        );
      }

      if (!mounted || !_running) return;
      setState(() {
        if (matched != null && matched.length >= 2) {
          _matchedRoute = matched;
          _lastMatchedPointCount = accepted.length;
          _lastMatchAt = now;
        }
        if (snapped != null) _snappedLive = snapped;
      });
    } finally {
      _mapMatchBusy = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) {
      _inBackground = false;
      _stopBackgroundKeepalive();
      _engine.markForegroundRecovery();
      _syncFromWallClock();
      _persistActiveRun(force: true);
      unawaited(_reacquireGps());
    } else if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive) &&
        _running) {
      _inBackground = true;
      _persistActiveRun(force: true);
      _startBackgroundKeepalive();
    }
  }

  bool _inBackground = false;
  Timer? _bgKeepalive;

  void _startBackgroundKeepalive() {
    _bgKeepalive?.cancel();
    _bgKeepalive = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_running || _finishing || !_inBackground) return;
      final pos = await GpsService.instance.getCurrentFix(
        timeLimit: const Duration(seconds: 6),
      );
      if (pos != null && _running) _onPosition(pos);
    });
  }

  void _stopBackgroundKeepalive() {
    _bgKeepalive?.cancel();
    _bgKeepalive = null;
  }

  /// Após tela apagada o Android pode silenciar o stream — força fix + reinicia.
  Future<void> _reacquireGps() async {
    if (!_running || _finishing) return;
    final current = await GpsService.instance.getCurrentFix(
      timeLimit: const Duration(seconds: 12),
    );
    if (!_running) return;
    if (current != null) {
      _onPosition(current);
      if (mounted) {
        setState(() {
          _gpsLost = false;
          _gpsStatus = _engine.isPaused
              ? (_manualPaused
                  ? 'Pausado — toque em Retomar'
                  : 'Auto-pause — ande para continuar')
              : 'GPS retomado — ${_engine.acceptedPoints.length} pontos';
        });
      }
    }
    if (!_running || _finishing) return;
    await _restartGpsStreamOnly();
  }

  Future<void> _loadWorkout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workout = await CardioService.instance.getActiveWorkout();
      try {
        final profile = await ProfileService.instance.getProfile();
        _weightKg = CalorieEstimator.resolveWeight(profile.currentWeightKg);
      } catch (_) {}
      _gpsConfig = await GpsConfigStore.instance.load();
      _autoPauseEnabled = _gpsConfig.autoPauseEnabled;
      _engine.applyConfig(_gpsConfig);
      // Remote defaults (best-effort).
      try {
        final remote = await AuthService.instance.get('/api/student/gps-config');
        _gpsConfig = await GpsConfigStore.instance.applyRemote(remote);
        _autoPauseEnabled = _gpsConfig.autoPauseEnabled;
        _engine.applyConfig(_gpsConfig);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _workout = workout;
        _intervals = workout?.intervals ?? [];
        _loading = false;
      });
      await _offerResumeIfNeeded();
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
      await _offerResumeIfNeeded();
    }
  }

  Future<void> _emitDiagnostic(
    GpsDiagnosticEvent type, {
    String? message,
  }) async {
    await GpsDiagnosticStore.instance.add(
      GpsDiagnosticEventRecord(
        eventType: type,
        timestamp: DateTime.now(),
        message: message,
        latitude: _engine.liveLatitude,
        longitude: _engine.liveLongitude,
        clientSessionId: _clientSessionId,
      ),
    );
  }

  int get _liveCalories {
    return CaloriesService.instance.cardioKcal(
      weightKg: _weightKg,
      avgSpeedKmh: _engine.averageSpeedKmh,
      elapsedMs: _elapsed * 1000,
      distanceMeters: _engine.distanceMeters,
    );
  }

  Future<void> _offerResumeIfNeeded() async {
    final snapshot = await ActiveRunStore.instance.load();
    if (snapshot == null || !mounted || _running) return;

    final age = DateTime.now().difference(snapshot.startedAt);
    if (age > const Duration(hours: 12)) {
      await ActiveRunStore.instance.clear();
      return;
    }

    if (widget.autoResume) {
      await _resumeFromSnapshot(snapshot);
      return;
    }

    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Corrida em andamento'),
        content: Text(
          'Há um treino interrompido '
          '(${(snapshot.distanceMeters / 1000).toStringAsFixed(2)} km, '
          '${_fmt(snapshot.movingElapsedSec > 0 ? snapshot.movingElapsedSec : snapshot.elapsedSec)}).\n\n'
          'Deseja continuar o monitoramento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (resume == true) {
      await _resumeFromSnapshot(snapshot);
    } else {
      await ActiveRunStore.instance.clear();
    }
  }

  Future<void> _resumeFromSnapshot(ActiveRunSnapshot snapshot) async {
    if (!await LocationPermissionHelper.ensureTrackingPermissions(context)) {
      return;
    }

    _engine.restore(
      points: snapshot.points,
      distanceMeters: snapshot.distanceMeters,
      estimatedGapMeters: snapshot.estimatedGapMeters,
      elevationGainMeters: snapshot.elevationGainMeters,
      movingElapsedSec: snapshot.movingElapsedSec > 0
          ? snapshot.movingElapsedSec
          : snapshot.elapsedSec,
      pausedSec: snapshot.pausedSec,
      pauseCount: snapshot.pauseCount,
      splits: snapshot.splits,
      autoPaused: snapshot.autoPaused,
      manualPaused: snapshot.manualPaused,
      runStartedAt: snapshot.startedAt,
    );

    setState(() {
      _clientSessionId = snapshot.clientSessionId;
      _session = snapshot.serverSessionId != null
          ? CardioSession(id: snapshot.serverSessionId!)
          : null;
      _running = true;
      _distance = snapshot.distanceMeters;
      _estimatedGap = snapshot.estimatedGapMeters;
      _elapsed = _engine.movingElapsedSec;
      _autoPaused = snapshot.autoPaused;
      _manualPaused = snapshot.manualPaused;
      _phaseIndex = snapshot.phaseIndex.clamp(
        0,
        _intervals.isEmpty ? 0 : _intervals.length - 1,
      );
      _startedAt = snapshot.startedAt;
      _gpsStatus = snapshot.manualPaused
          ? 'Pausado — toque em Retomar'
          : 'Retomando GPS...';
      _gpsLost = false;
      _lastCloudSeq = snapshot.points.isEmpty ? 0 : snapshot.points.last.sequenceNum + 1;
    });

    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _syncFromWallClock(),
    );
    _startGpsWatchdog();
    _startMotionSensor();
    await _startGpsTracking();
  }

  LocationSettings get _locationSettings {
    final calories = _liveCalories;
    final notifText = OutdoorWorkoutService.instance.formatNotificationText(
      paused: _engine.isPaused,
      manualPaused: _manualPaused,
      distanceMeters: _distance,
      paceSecPerKm: _engine.currentPaceSecPerKm,
      speedKmh: _engine.displaySpeedKmh,
      calories: calories,
      elapsedSec: _elapsed,
    );

    return GpsService.instance.buildSettings(
      notificationTitle: _engine.isPaused
          ? 'Corrida pausada'
          : 'Corrida em andamento',
      notificationText: notifText,
    );
  }

  Future<void> _startGpsTracking() async {
    setState(() {
      _gpsStatus = 'Buscando sinal GPS...';
      _gpsLost = false;
    });
    final current = await GpsService.instance.getCurrentFix();
    if (current != null) {
      _onPosition(current);
      if (mounted && !_gpsLost) {
        setState(() => _gpsStatus = 'GPS ok — pode apagar a tela');
      }
    } else if (mounted) {
      setState(
        () => _gpsStatus =
            'Sem fix ainda — mantenha o GPS ligado e vá para área aberta',
      );
    }

    await _gpsSub?.cancel();
    _gpsSub = GpsService.instance.listen(
      settings: _locationSettings,
      onPosition: _onPosition,
      onError: (Object err) {
        if (mounted) {
          setState(() => _gpsStatus = 'Erro no GPS: $err');
        }
      },
    );
  }

  void _startGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_running || _finishing) return;
      final lost = !_engine.hasGpsSignal;
      final pausedChanged = _autoPaused != _engine.autoPaused ||
          _manualPaused != _engine.manualPaused;
      if ((lost != _gpsLost || pausedChanged) && mounted) {
        if (lost && !_wasGpsLost) {
          unawaited(_emitDiagnostic(
            GpsDiagnosticEvent.gpsLost,
            message: 'Sinal GPS fraco ou ausente',
          ));
        } else if (!lost && _wasGpsLost) {
          unawaited(_emitDiagnostic(
            GpsDiagnosticEvent.gpsRecovered,
            message: 'Sinal GPS recuperado',
          ));
        }
        _wasGpsLost = lost;
        setState(() {
          _gpsLost = lost && !_engine.isPaused;
          _autoPaused = _engine.autoPaused;
          _manualPaused = _engine.manualPaused;
          _gpsStatus = _engine.manualPaused
              ? 'Pausado — toque em Retomar'
              : _engine.autoPaused
                  ? 'Auto-pause — ande para continuar'
                  : lost
                      ? 'Aguardando fix GPS (sinal fraco ou tela apagada)...'
                      : 'GPS ok — ${_engine.acceptedPoints.length} pontos';
        });
      }
    });
  }

  void _startClocks() {
    _startedAt = DateTime.now();
    _elapsed = 0;
    _phaseIndex = 0;
    _phaseRemaining = _intervals.isNotEmpty ? _intervals.first.durationSec : 0;
    _matchedRoute = [];
    _snappedLive = null;
    _lastMatchedPointCount = 0;
    _lastMatchAt = null;
    _engine.markRunStarted(_startedAt!);
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _syncFromWallClock(),
    );
    _startGpsWatchdog();
    _startMotionSensor();
  }

  void _syncFromWallClock() {
    if (!_running || _finishing) return;
    _engine.tickMovingTime(DateTime.now());

    final elapsed = _engine.movingElapsedSec;
    if (elapsed < 0) return;

    var phaseIndex = _phaseIndex;
    var phaseRemaining = _phaseRemaining;
    var phaseChanged = false;

    if (_intervals.isNotEmpty && !_engine.isPaused) {
      var cursor = elapsed;
      var finished = true;
      for (var i = 0; i < _intervals.length; i++) {
        final dur = _intervals[i].durationSec;
        if (cursor < dur) {
          phaseIndex = i;
          phaseRemaining = dur - cursor;
          finished = false;
          break;
        }
        cursor -= dur;
      }
      if (finished) {
        if (!_finishing) {
          unawaited(CardioFeedback.playFinish());
          unawaited(_finish(auto: true));
        }
        return;
      }
      if (phaseIndex != _phaseIndex) {
        phaseChanged = true;
      }
    }

    if (!mounted) return;
    // Tempo real: atualiza tempo + distância/velocidade ao vivo a cada tick.
    setState(() {
      _elapsed = elapsed;
      _distance = _engine.distanceMeters;
      _estimatedGap = _engine.estimatedGapMeters;
      _autoPaused = _engine.autoPaused;
      _manualPaused = _engine.manualPaused;
      _phaseIndex = phaseIndex;
      _phaseRemaining = phaseRemaining;
    });
    if (phaseChanged) {
      unawaited(CardioFeedback.playPhase(_intervals[phaseIndex].phase));
    }
    if (elapsed > 0 &&
        elapsed % 10 == 0 &&
        _lastPersistElapsedSec != elapsed) {
      _lastPersistElapsedSec = elapsed;
      unawaited(_persistActiveRun());
    }
    if (elapsed > 0 &&
        elapsed % 30 == 0 &&
        _lastCloudElapsedSec != elapsed) {
      _lastCloudElapsedSec = elapsed;
      unawaited(_cloudBackup());
    }
  }

  Future<void> _persistActiveRun({bool force = false}) async {
    if (!_running || _clientSessionId == null || _startedAt == null) return;
    await ActiveRunStore.instance.save(
      ActiveRunSnapshot(
        clientSessionId: _clientSessionId!,
        serverSessionId: _session?.id,
        workoutId: _workout?.id,
        startedAt: _startedAt!,
        distanceMeters: _distance,
        estimatedGapMeters: _estimatedGap,
        elevationGainMeters: _engine.elevationGainMeters,
        elapsedSec: _elapsed,
        movingElapsedSec: _engine.movingElapsedSec,
        phaseIndex: _phaseIndex,
        autoPaused: _engine.autoPaused,
        manualPaused: _engine.manualPaused,
        pausedSec: _engine.pausedSec,
        pauseCount: _engine.pauseCount,
        points: _engine.acceptedPoints,
        splits: _engine.splits,
      ),
      force: force,
    );
  }

  Future<void> _cloudBackup() async {
    final session = _session;
    if (session == null || !_running) return;
    final now = DateTime.now();
    if (_lastCloudBackupAt != null &&
        now.difference(_lastCloudBackupAt!) < const Duration(seconds: 25)) {
      return;
    }
    final pending = _engine.acceptedPoints
        .where((p) => p.sequenceNum >= _lastCloudSeq)
        .map((p) => p.toJson())
        .toList();
    if (pending.isEmpty) return;
    // API limita a 500 pontos por request.
    final chunk = pending.take(500).toList();
    try {
      await CardioService.instance.backupRoutePoints(
        sessionId: session.id,
        points: chunk,
      );
      _lastCloudSeq = (chunk.last['sequenceNum'] as num).toInt() + 1;
      _lastCloudBackupAt = now;
    } catch (_) {
      // Best-effort — local + sync final cobrem falhas.
    }
  }

  Future<void> _start() async {
    if (_running || _finishing) return;
    if (!await LocationPermissionHelper.ensureTrackingPermissions(context)) {
      return;
    }
    if (!mounted) return;
    await LocationPermissionHelper.promptBatteryOptimizationIfNeeded(context);
    if (!mounted) return;

    setState(() {
      _error = null;
      _finishing = false;
    });

    _clientSessionId = const Uuid().v4();
    _engine.reset();
    _engine.applyConfig(_gpsConfig.copyWith(autoPauseEnabled: _autoPauseEnabled));
    _engine.setAutoPauseEnabled(_autoPauseEnabled);
    _wasGpsLost = false;
    _lastCloudSeq = 0;
    _lastCloudBackupAt = null;
    await ActiveRunStore.instance.clear();

    try {
      final session = await CardioService.instance.startSession(
        workoutId: _workout?.id,
        clientSessionId: _clientSessionId!,
      );
      if (!mounted) return;

      setState(() {
        _session = session;
        _running = true;
        _distance = 0;
        _estimatedGap = 0;
        _gpsLost = false;
        _autoPaused = false;
        _manualPaused = false;
      });

      if (_intervals.isNotEmpty) {
        await CardioFeedback.playPhase(_intervals.first.phase);
      } else {
        await CardioFeedback.playBeeps(1);
      }

      _startClocks();
      await _persistActiveRun(force: true);
      await _startGpsTracking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS em segundo plano ativo — pode apagar a tela'),
          duration: Duration(seconds: 3),
        ),
      );
    } on SessionExpiredException {
      if (!mounted) return;
      setState(() => _error = 'Sessão expirada. Faça login novamente.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _session = null;
        _running = true;
        _distance = 0;
        _estimatedGap = 0;
        _gpsLost = false;
        _autoPaused = false;
        _manualPaused = false;
      });
      if (_intervals.isNotEmpty) {
        await CardioFeedback.playPhase(_intervals.first.phase);
      } else {
        await CardioFeedback.playBeeps(1);
      }
      _startClocks();
      await _persistActiveRun(force: true);
      await _startGpsTracking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Modo offline — GPS em segundo plano; sincroniza ao finalizar',
          ),
        ),
      );
    }
  }

  void _onPosition(Position pos) {
    if (!_running) return;
    _engine.tickMovingTime(DateTime.now());
    final wasPaused = _engine.isPaused;
    final result = _engine.process(pos);

    _distance = _engine.distanceMeters;
    _estimatedGap = _engine.estimatedGapMeters;

    if (result.newSplit != null) {
      final s = result.newSplit!;
      _lastSplitToast =
          'Km ${s.km}: ${GpsTrackingEngine.formatPace(s.paceSecPerKm)}';
      unawaited(CardioFeedback.playBeeps(1));
    }

    if (!mounted) return;
    // Todo o painel em tempo real a cada fix GPS (~200 ms).
    setState(() {
      _elapsed = _engine.movingElapsedSec.clamp(0, 86400 * 7);
      _gpsLost = false;
      _autoPaused = result.autoPaused;
      _manualPaused = result.manualPaused;
      if (result.manualPaused) {
        _gpsStatus = 'Pausado — toque em Retomar';
      } else if (result.autoPaused) {
        _gpsStatus = 'Auto-pause — ande para continuar';
      } else if (wasPaused && !result.isPaused) {
        _gpsStatus =
            'Retomado — ${_engine.displaySpeedKmh.toStringAsFixed(1)} km/h';
      } else if (_engine.acceptedPoints.length < 2) {
        _gpsStatus = 'GPS ok — pode apagar a tela';
      } else {
        _gpsStatus =
            '${_engine.displaySpeedKmh.toStringAsFixed(1)} km/h · '
            'ritmo ${GpsTrackingEngine.formatPace(_engine.currentPaceSecPerKm)} · '
            '${_engine.acceptedPoints.length} pts';
      }
    });

    // Persistência em background, não a cada fix (evita travar a UI).
    final now = DateTime.now();
    if (_lastPersistAt == null ||
        now.difference(_lastPersistAt!) >= const Duration(seconds: 5)) {
      _lastPersistAt = now;
      unawaited(_persistActiveRun());
    }
    unawaited(_refreshMapMatching());
  }

  Future<void> _restartGpsStreamOnly() async {
    if (!_running || _finishing) return;
    await _gpsSub?.cancel();
    _gpsSub = GpsService.instance.listen(
      settings: _locationSettings,
      onPosition: _onPosition,
      onError: (Object err) {
        if (mounted) {
          setState(() => _gpsStatus = 'Erro no GPS: $err');
        }
      },
    );
  }

  void _toggleManualPause() {
    if (!_running || _finishing) return;
    _engine.toggleManualPause();
    setState(() {
      _manualPaused = _engine.manualPaused;
      _autoPaused = _engine.autoPaused;
      _gpsLost = false;
      _gpsStatus = _manualPaused
          ? 'Pausado — toque em Retomar'
          : 'Retomado — continue o treino';
    });
    unawaited(_persistActiveRun(force: true));
    unawaited(CardioFeedback.playBeeps(1));
  }

  void _startMotionSensor() {
    _accelSub?.cancel();
    try {
      _accelSub = accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 200),
      ).listen((e) {
        if (!_running || _finishing) return;
        _engine.notePhoneAcceleration(e.x, e.y, e.z);
      });
    } catch (_) {
      // Emulador / plataforma sem acelerômetro — GPS sozinho.
    }
  }

  void _stopMotionSensor() {
    _accelSub?.cancel();
    _accelSub = null;
  }

  Future<void> _export(String format) async {
    final points = _engine.acceptedPoints;
    if (points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem pontos GPS para exportar')),
      );
      return;
    }
    final title = _workout?.title ?? 'Treino outdoor';
    final started = _startedAt ?? points.first.recordedAt;
    try {
      if (format == 'gpx') {
        await RunExportService.instance.shareGpx(
          points: points,
          title: title,
          startedAt: started,
          distanceMeters: _distance + _estimatedGap,
          elevationGainMeters: _engine.elevationGainMeters,
        );
      } else {
        await RunExportService.instance.shareTcx(
          points: points,
          title: title,
          startedAt: started,
          elapsedSec: _engine.movingElapsedSec,
          distanceMeters: _distance + _estimatedGap,
          elevationGainMeters: _engine.elevationGainMeters,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao exportar: $e')),
      );
    }
  }

  Future<void> _finish({bool auto = false}) async {
    if (_finishing) return;
    _finishing = true;
    _stopMotionSensor();
    _stopBackgroundKeepalive();
    await _gpsSub?.cancel();
    _gpsSub = null;
    _clockTimer?.cancel();
    _clockTimer = null;
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;

    _elapsed = _engine.movingElapsedSec.clamp(0, 86400 * 7);

    if (mounted) {
      setState(() => _running = false);
    }

    // Fecha o último intervalo de pausa/movimento antes de enviar.
    _engine.tickMovingTime(DateTime.now());
    _elapsed = _engine.movingElapsedSec.clamp(0, 86400 * 7);

    final totalDistance = _distance; // km oficial (sem gap inventado)
    final avgSpeedKmh = _engine.averageSpeedKmh > 0
        ? _engine.averageSpeedKmh
        : (_elapsed > 0 ? (totalDistance / 1000) / (_elapsed / 3600) : 0.0);
    final elapsedMs = _elapsed * 1000;
    final pausedMs = _engine.pausedMs;
    final pauseCount = _engine.pauseCount;
    final caloriesKcal = CaloriesService.instance.cardioKcal(
      weightKg: _weightKg,
      avgSpeedKmh: avgSpeedKmh,
      elapsedMs: elapsedMs,
      distanceMeters: totalDistance,
    );
    final quality = GpsQualityService.instance.evaluate(
      acceptedPoints: _engine.acceptedPoints,
      rejectCounts: Map.of(_engine.rejectCounts),
      gpsGapSec: _engine.gpsGapSec,
    );
    final points = _engine.pointsForSync();

    // Oferece exportação antes de sair.
    if (mounted && points.length >= 2) {
      final export = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Treino finalizado'),
          content: Text(
            'GPS: ${quality.display}\n'
            'Estimativa: $caloriesKcal kcal\n\n'
            'Deseja exportar a rota (GPX/TCX)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Agora não'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'gpx'),
              child: const Text('GPX'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'tcx'),
              child: const Text('TCX'),
            ),
          ],
        ),
      );
      if (export != null) {
        await _export(export);
      }
    }

    try {
      if (_session != null) {
        await CardioService.instance.completeSession(
          sessionId: _session!.id,
          distanceMeters: totalDistance,
          avgSpeedKmh: avgSpeedKmh,
          elapsedMs: elapsedMs,
          pausedMs: pausedMs,
          pauseCount: pauseCount,
          caloriesKcal: caloriesKcal,
          gpsQualityScore: quality.score,
          gpsQualityLabel: quality.label,
          gpsAlgorithmVersion: _gpsConfig.gpsAlgorithmVersion,
          filterVersion: _gpsConfig.filterVersion,
          kalmanVersion: _gpsConfig.kalmanVersion,
          distanceVersion: _gpsConfig.distanceVersion,
          caloriesVersion: _gpsConfig.caloriesVersion,
          gpsConfigSnapshot: jsonEncode(_gpsConfig.toJson()),
          points: points,
        );
      } else {
        final payload = {
          'clientSessionId': _clientSessionId ?? const Uuid().v4(),
          'workoutId': _workout?.id,
          'startedAt': (_startedAt ?? DateTime.now()).toUtc().toIso8601String(),
          'completedAt': DateTime.now().toUtc().toIso8601String(),
          'distanceMeters': totalDistance,
          'avgSpeedKmh': avgSpeedKmh,
          'elapsedMs': elapsedMs,
          'pausedMs': pausedMs,
          'pauseCount': pauseCount,
          'caloriesKcal': caloriesKcal,
          'gpsQualityScore': quality.score,
          'gpsQualityLabel': quality.label,
          'gpsAlgorithmVersion': _gpsConfig.gpsAlgorithmVersion,
          'filterVersion': _gpsConfig.filterVersion,
          'kalmanVersion': _gpsConfig.kalmanVersion,
          'distanceVersion': _gpsConfig.distanceVersion,
          'caloriesVersion': _gpsConfig.caloriesVersion,
          'gpsConfigSnapshot': jsonEncode(_gpsConfig.toJson()),
          'points': points,
          if (_estimatedGap > 0) 'estimatedGapMeters': _estimatedGap,
        };
        try {
          await AuthService.instance.post('/api/student/sync', {
            'measurements': [],
            'cardioSessions': [payload],
          });
        } catch (_) {
          await SyncService.instance.queue('cardio_session', payload);
          await ActiveRunStore.instance.clear();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salvo offline — sincronize depois')),
          );
          _finishing = false;
          return;
        }
      }
      await ActiveRunStore.instance.clear();
      // Health opt-in + compartilhar resumo (best-effort).
      try {
        await HealthSyncService.instance.load();
        await HealthSyncService.instance.syncCompletedSession(
          CardioSession(
            id: _session?.id ?? _clientSessionId ?? '',
            workoutTitle: _workout?.title ?? 'Treino outdoor',
            startedAt: _startedAt,
            completedAt: DateTime.now(),
            distanceMeters: totalDistance,
            avgSpeedKmh: avgSpeedKmh,
            elapsedMs: elapsedMs,
            caloriesKcal: caloriesKcal,
            gpsQualityScore: quality.score,
            gpsQualityLabel: quality.label,
            routePoints: _engine.acceptedPoints,
          ),
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? 'Intervalos concluídos — treino sincronizado!'
                : 'Treino sincronizado na nuvem!',
          ),
          action: SnackBarAction(
            label: 'Compartilhar',
            onPressed: () {
              unawaited(
                ActivityShareService.instance.shareSummary(
                  title: _workout?.title ?? 'Treino outdoor',
                  distanceMeters: totalDistance,
                  elapsedMs: elapsedMs,
                  avgSpeedKmh: avgSpeedKmh,
                  caloriesKcal: caloriesKcal,
                  gpsQualityScore: quality.score,
                  gpsQualityLabel: quality.label,
                  completedAt: DateTime.now(),
                ),
              );
            },
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      final payload = {
        'clientSessionId': _clientSessionId ?? const Uuid().v4(),
        'workoutId': _workout?.id,
        'startedAt': (_startedAt ?? DateTime.now()).toUtc().toIso8601String(),
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'distanceMeters': totalDistance,
        'avgSpeedKmh': avgSpeedKmh,
        'elapsedMs': elapsedMs,
        'pausedMs': pausedMs,
        'pauseCount': pauseCount,
        'caloriesKcal': caloriesKcal,
        'points': points,
        if (_estimatedGap > 0) 'estimatedGapMeters': _estimatedGap,
      };
      await SyncService.instance.queue('cardio_session', payload);
      await ActiveRunStore.instance.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvo offline — sincronize depois')),
      );
    } finally {
      _finishing = false;
    }
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  CardioInterval? get _currentPhase =>
      _intervals.isNotEmpty && _phaseIndex < _intervals.length
          ? _intervals[_phaseIndex]
          : null;

  double get _avgSpeedKmh => _engine.averageSpeedKmh;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_running) {
      unawaited(_persistActiveRun(force: true));
    }
    _stopMotionSensor();
    _stopBackgroundKeepalive();
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    _gpsWatchdog?.cancel();
    _mapMatching.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _currentPhase;
    final title = _workout?.title ?? 'Corrida/caminhada livre';
    final mapPoints = _mapRoutePoints;
    final currentPace =
        GpsTrackingEngine.formatPace(_engine.currentPaceSecPerKm);
    final avgPace = GpsTrackingEngine.formatPace(_engine.averagePaceSecPerKm);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino outdoor'),
        actions: [
          if (_engine.acceptedPoints.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'Exportar',
              onSelected: (v) => unawaited(_export(v)),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'gpx', child: Text('Exportar GPX')),
                PopupMenuItem(value: 'tcx', child: Text('Exportar TCX')),
              ],
              icon: const Icon(Icons.ios_share),
            ),
          if (!_running)
            IconButton(
              onPressed: _loading ? null : _loadWorkout,
              icon: const Icon(Icons.refresh),
              tooltip: 'Atualizar treino',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_running) ...[
                      const SizedBox(height: 6),
                      Text(
                        _manualPaused
                            ? 'Pausado — o tempo em movimento está congelado'
                            : _autoPaused
                                ? 'Auto-pause ativo — ande para retomar'
                                : _gpsLost
                                    ? 'Sinal de GPS perdido. Tentando reconectar...'
                                    : 'Pode apagar a tela — GPS + backup na nuvem ativos',
                        style: TextStyle(
                          color: _manualPaused || _autoPaused || _gpsLost
                              ? Colors.orangeAccent
                              : Colors.lightGreenAccent,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          RouteMapView(
                            height: 220,
                            statusMessage: _running
                                ? (_gpsStatus ?? 'Buscando sinal GPS...')
                                : 'Inicie para começar o rastreio GPS',
                            liveLatitude: _running
                                ? (_snappedLive?.latitude ??
                                    _engine.liveLatitude)
                                : null,
                            liveLongitude: _running
                                ? (_snappedLive?.longitude ??
                                    _engine.liveLongitude)
                                : null,
                            points: mapPoints,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _Stat('Tempo', _fmt(_elapsed))),
                              Expanded(
                                child: _Stat(
                                  'Pausado',
                                  _fmt(_engine.pausedSec),
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  'Distância',
                                  '${(_engine.distanceMeters / 1000).toStringAsFixed(2)} km',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat('Ritmo agora', currentPace),
                              ),
                              Expanded(child: _Stat('Ritmo médio', avgPace)),
                              Expanded(
                                child: _Stat(
                                  'Elevação +',
                                  '${_engine.elevationGainMeters.toStringAsFixed(0)} m',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  'Vel. agora',
                                  '${_engine.displaySpeedKmh.toStringAsFixed(1)} km/h',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  'Vel. média',
                                  '${_avgSpeedKmh.toStringAsFixed(1)} km/h',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  'Pausas',
                                  '${_engine.pauseCount}',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  'Calorias*',
                                  '$_liveCalories kcal',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '*Estimativa MET (peso × intensidade × tempo)',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          if (_lastSplitToast != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _lastSplitToast!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (_engine.splits.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Splits por km',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            ..._engine.splits.reversed.take(8).map(
                                  (s) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Km ${s.km}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          GpsTrackingEngine.formatPace(
                                            s.paceSecPerKm,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '+${s.elevationGainMeters.toStringAsFixed(0)} m',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          ],
                          const SizedBox(height: 12),
                          if (phase != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: phase.isRun
                                    ? const Color(0xFF7F1D1D)
                                    : const Color(0xFF14532D),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: phase.isRun
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    phase.isRun ? 'CORRIDA' : 'CAMINHADA',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _fmt(_phaseRemaining),
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Fase ${_phaseIndex + 1} de ${_intervals.length}'
                                    '${_manualPaused || _autoPaused ? ' · pausado' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                _running
                                    ? (_gpsStatus ??
                                        'GPS ativo · ${_engine.acceptedPoints.length} pontos')
                                    : 'Inicie para começar o rastreio GPS',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Auto-pause',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Pausa se ficar parado (~30s)',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      value: _autoPauseEnabled,
                      onChanged: (v) {
                        setState(() => _autoPauseEnabled = v);
                        _engine.setAutoPauseEnabled(v);
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _running || _finishing ? null : _start,
                            child: const Text('Iniciar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _manualPaused
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            onPressed: _running && !_finishing
                                ? _toggleManualPause
                                : null,
                            child: Text(_manualPaused ? 'Retomar' : 'Pausar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: _running && !_finishing
                                ? () => _finish()
                                : null,
                            child:
                                Text(_finishing ? 'Salvando...' : 'Finalizar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
