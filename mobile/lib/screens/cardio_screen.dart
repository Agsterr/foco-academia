import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/cardio_feedback.dart';
import '../services/cardio_service.dart';
import '../services/gps_tracking_engine.dart';
import '../services/location_permission_helper.dart';
import '../services/run_export_service.dart';
import '../services/sync_service.dart';
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
  Timer? _clockTimer;
  Timer? _gpsWatchdog;

  CardioWorkout? _workout;
  CardioSession? _session;
  List<CardioInterval> _intervals = [];
  int _phaseIndex = 0;
  int _phaseRemaining = 0;

  final _engine = GpsTrackingEngine();
  double _distance = 0;
  double _estimatedGap = 0;
  int _elapsed = 0;
  bool _running = false;
  bool _loading = true;
  bool _finishing = false;
  bool _autoPaused = false;
  String? _error;
  String? _clientSessionId;
  String? _gpsStatus;
  DateTime? _startedAt;
  bool _gpsLost = false;
  int _lastCloudSeq = 0;
  DateTime? _lastCloudBackupAt;
  String? _lastSplitToast;

  List<TrackedPoint> get _displayPoints => _engine.smoothedRoute();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWorkout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) {
      _syncFromWallClock();
      _persistActiveRun(force: true);
    } else if (state == AppLifecycleState.paused && _running) {
      _persistActiveRun(force: true);
    }
  }

  Future<void> _loadWorkout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final workout = await CardioService.instance.getActiveWorkout();
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
      splits: snapshot.splits,
      autoPaused: snapshot.autoPaused,
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
      _phaseIndex = snapshot.phaseIndex.clamp(
        0,
        _intervals.isEmpty ? 0 : _intervals.length - 1,
      );
      _startedAt = snapshot.startedAt;
      _gpsStatus = 'Retomando GPS...';
      _gpsLost = false;
      _lastCloudSeq = snapshot.points.isEmpty ? 0 : snapshot.points.last.sequenceNum + 1;
    });

    _clockTimer?.cancel();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _syncFromWallClock());
    _startGpsWatchdog();
    await _startGpsTracking();
  }

  LocationSettings get _locationSettings {
    final km = (_distance / 1000).toStringAsFixed(1);
    final pace = GpsTrackingEngine.formatPace(_engine.currentPaceSecPerKm);
    final notifText = _autoPaused
        ? 'Pausado · $km km'
        : 'Distância: $km km · Ritmo: $pace';

    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 2),
        forceLocationManager: false,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: _autoPaused
              ? 'Corrida pausada'
              : 'Corrida em andamento',
          notificationText: notifText,
          notificationChannelName: 'Treino outdoor',
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon:
              const AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.fitness,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
    );
  }

  Future<void> _startGpsTracking() async {
    setState(() {
      _gpsStatus = 'Buscando sinal GPS...';
      _gpsLost = false;
    });
    try {
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        forceAndroidLocationManager: false,
        timeLimit: const Duration(seconds: 20),
      );
      _onPosition(current);
      if (mounted && !_gpsLost) {
        setState(() => _gpsStatus = 'GPS ok — pode apagar a tela');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _gpsStatus =
              'Sem fix ainda — mantenha o GPS ligado e vá para área aberta',
        );
      }
    }

    await _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(locationSettings: _locationSettings)
        .listen(
      _onPosition,
      onError: (Object err) {
        if (mounted) {
          setState(() => _gpsStatus = 'Erro no GPS: $err');
        }
      },
    );
  }

  void _startGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_running || _finishing) return;
      final since = _engine.timeSinceLastFix;
      final lost = since == null || since > _engine.gpsLossTimeout;
      if ((lost != _gpsLost || _autoPaused != _engine.autoPaused) && mounted) {
        setState(() {
          _gpsLost = lost && !_engine.autoPaused;
          _autoPaused = _engine.autoPaused;
          _gpsStatus = _engine.autoPaused
              ? 'Auto-pause — parado. Ande para continuar.'
              : lost
                  ? 'Sinal de GPS perdido. Tentando reconectar...'
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
    _clockTimer?.cancel();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _syncFromWallClock());
    _startGpsWatchdog();
  }

  void _syncFromWallClock() {
    if (!_running || _finishing) return;
    _engine.tickMovingTime(DateTime.now());

    final elapsed = _engine.movingElapsedSec;
    if (elapsed < 0) return;

    var phaseIndex = _phaseIndex;
    var phaseRemaining = _phaseRemaining;
    var phaseChanged = false;

    if (_intervals.isNotEmpty && !_engine.autoPaused) {
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
    setState(() {
      _elapsed = elapsed;
      _autoPaused = _engine.autoPaused;
      _phaseIndex = phaseIndex;
      _phaseRemaining = phaseRemaining;
    });
    if (phaseChanged) {
      unawaited(CardioFeedback.playPhase(_intervals[phaseIndex].phase));
    }
    if (elapsed % 10 == 0) {
      unawaited(_persistActiveRun());
    }
    if (elapsed % 30 == 0) {
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
    _lastCloudSeq = 0;
    _lastCloudBackupAt = null;

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
    final wasPaused = _engine.autoPaused;
    final result = _engine.process(pos);

    if (result.autoPaused != wasPaused && mounted) {
      setState(() {
        _autoPaused = result.autoPaused;
        _gpsStatus = result.autoPaused
            ? 'Auto-pause — parado. Ande para continuar.'
            : 'Retomado — ${_activityLabel(result.activity)}';
      });
    }

    if (!result.accepted) {
      if (result.rejectReason == GpsRejectReason.autoPaused && mounted) {
        setState(() => _autoPaused = true);
      }
      return;
    }

    _distance = _engine.distanceMeters;
    _estimatedGap = _engine.estimatedGapMeters;

    if (result.newSplit != null) {
      final s = result.newSplit!;
      _lastSplitToast =
          'Km ${s.km}: ${GpsTrackingEngine.formatPace(s.paceSecPerKm)}';
      unawaited(CardioFeedback.playBeeps(1));
    }

    if (mounted) {
      setState(() {
        _gpsLost = false;
        _autoPaused = false;
        _gpsStatus = _engine.acceptedPoints.length < 2
            ? 'GPS ok — pode apagar a tela'
            : '${_activityLabel(result.activity)} · '
                '${_engine.acceptedPoints.length} pts · '
                'ritmo ${GpsTrackingEngine.formatPace(_engine.currentPaceSecPerKm)}';
      });
    }
    unawaited(_persistActiveRun());
  }

  String _activityLabel(MotionActivity a) {
    switch (a) {
      case MotionActivity.run:
        return 'Correndo';
      case MotionActivity.walk:
        return 'Caminhando';
      case MotionActivity.stopped:
        return 'Parado';
    }
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

    final totalDistance = _distance + _estimatedGap;
    final avgSpeedKmh =
        _elapsed > 0 ? (totalDistance / 1000) / (_elapsed / 3600) : 0.0;
    final elapsedMs = _elapsed * 1000;
    final points = _engine.pointsForSync();

    // Oferece exportação antes de sair.
    if (mounted && points.length >= 2) {
      final export = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Treino finalizado'),
          content: const Text('Deseja exportar a rota (GPX/TCX)?'),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? 'Intervalos concluídos — treino sincronizado!'
                : 'Treino sincronizado na nuvem!',
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

  double get _avgSpeedKmh =>
      _elapsed > 0 ? ((_distance + _estimatedGap) / 1000) / (_elapsed / 3600) : 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_running) {
      unawaited(_persistActiveRun(force: true));
    }
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    _gpsWatchdog?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _currentPhase;
    final title = _workout?.title ?? 'Corrida/caminhada livre';
    final mapPoints = _displayPoints;
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
                        _autoPaused
                            ? 'Auto-pause ativo — ande para retomar'
                            : _gpsLost
                                ? 'Sinal de GPS perdido. Tentando reconectar...'
                                : 'Pode apagar a tela — GPS + backup na nuvem ativos',
                        style: TextStyle(
                          color: _autoPaused || _gpsLost
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
                            points: mapPoints
                                .map(
                                  (p) => RoutePointView(
                                    latitude: p.latitude,
                                    longitude: p.longitude,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _Stat('Tempo', _fmt(_elapsed))),
                              Expanded(
                                child: _Stat(
                                  'Distância',
                                  '${(_distance / 1000).toStringAsFixed(2)} km',
                                ),
                              ),
                              Expanded(
                                child: _Stat('Ritmo agora', currentPace),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: _Stat('Ritmo médio', avgPace)),
                              Expanded(
                                child: _Stat(
                                  'Elevação +',
                                  '${_engine.elevationGainMeters.toStringAsFixed(0)} m',
                                ),
                              ),
                              Expanded(
                                child: _Stat(
                                  'Vel. média',
                                  '${_avgSpeedKmh.toStringAsFixed(1)} km/h',
                                ),
                              ),
                            ],
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
                                    '${_autoPaused ? ' · pausado' : ''}',
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
