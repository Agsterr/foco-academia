import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../services/auth_service.dart';
import '../services/cardio_feedback.dart';
import '../services/cardio_service.dart';
import '../services/sync_service.dart';
import '../widgets/route_map_view.dart';

class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key});

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> with WidgetsBindingObserver {
  StreamSubscription<Position>? _gpsSub;
  Timer? _clockTimer;

  CardioWorkout? _workout;
  CardioSession? _session;
  List<CardioInterval> _intervals = [];
  int _phaseIndex = 0;
  int _phaseRemaining = 0;

  final _points = <Map<String, dynamic>>[];
  double _distance = 0;
  int _elapsed = 0;
  bool _running = false;
  bool _loading = true;
  bool _finishing = false;
  String? _error;
  String? _clientSessionId;
  int _seq = 0;
  Position? _lastPos;
  String? _gpsStatus;
  DateTime? _startedAt;

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
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  LocationSettings get _locationSettings {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Treino outdoor em andamento',
          notificationText: 'Gravando GPS com a tela apagada — toque para voltar',
          notificationChannelName: 'Treino outdoor',
          enableWakeLock: true,
          setOngoing: true,
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
        ),
      );
    }
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }

  Future<void> _startGpsTracking() async {
    setState(() => _gpsStatus = 'Buscando sinal GPS...');
    try {
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        forceAndroidLocationManager: false,
        timeLimit: const Duration(seconds: 20),
      );
      _onPosition(current);
      if (mounted) {
        setState(() => _gpsStatus = 'GPS ok — pode apagar a tela');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gpsStatus = 'Sem fix ainda — mantenha o GPS ligado e vá para área aberta');
      }
    }

    await _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(locationSettings: _locationSettings).listen(
      (pos) {
        _onPosition(pos);
      },
      onError: (Object err) {
        if (mounted) {
          setState(() => _gpsStatus = 'Erro no GPS: $err');
        }
      },
    );
  }

  Future<bool> _ensureLocationPermission() async {
    if (!kIsWeb && Platform.isAndroid) {
      final notif = await Permission.notification.request();
      if (!notif.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ative notificações para gravar o GPS com a tela apagada'),
          ),
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de localização necessária')),
      );
      return false;
    }

    // Android 10+: precisa de "Permitir o tempo todo" para tela apagada / segundo plano.
    if (!kIsWeb && Platform.isAndroid && permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse) {
        final always = await Permission.locationAlways.request();
        if (!always.isGranted && mounted) {
          final open = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Localização em segundo plano'),
              content: const Text(
                'Para gravar a rota com a tela apagada, escolha '
                '"Permitir o tempo todo" nas configurações de localização.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Abrir configurações'),
                ),
              ],
            ),
          );
          if (open == true) {
            await Geolocator.openAppSettings();
          }
        }
      }
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative o GPS do aparelho')),
      );
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  void _startClocks() {
    _startedAt = DateTime.now();
    _elapsed = 0;
    _phaseIndex = 0;
    _phaseRemaining = _intervals.isNotEmpty ? _intervals.first.durationSec : 0;
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _syncFromWallClock());
  }

  void _syncFromWallClock() {
    if (!_running || _finishing || _startedAt == null) return;
    final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
    if (elapsed < 0) return;

    var phaseIndex = _phaseIndex;
    var phaseRemaining = _phaseRemaining;
    var phaseChanged = false;

    if (_intervals.isNotEmpty) {
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
      _phaseIndex = phaseIndex;
      _phaseRemaining = phaseRemaining;
    });
    if (phaseChanged) {
      unawaited(CardioFeedback.playBeeps(phaseIndex.clamp(1, 5)));
      unawaited(CardioFeedback.playPhase(_intervals[phaseIndex].phase));
    }
  }

  Future<void> _start() async {
    if (_running || _finishing) return;
    if (!await _ensureLocationPermission()) return;

    setState(() {
      _error = null;
      _finishing = false;
    });

    _clientSessionId = const Uuid().v4();
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
        _points.clear();
        _seq = 0;
        _lastPos = null;
      });

      if (_intervals.isNotEmpty) {
        await CardioFeedback.playBeeps(1);
        await CardioFeedback.playPhase(_intervals.first.phase);
      } else {
        await CardioFeedback.playBeeps(1);
      }

      _startClocks();
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
      // Offline: inicia local e sincroniza no fim via fila.
      if (!mounted) return;
      setState(() {
        _session = null;
        _running = true;
        _distance = 0;
        _points.clear();
        _seq = 0;
        _lastPos = null;
      });
      await CardioFeedback.playBeeps(1);
      if (_intervals.isNotEmpty) {
        await CardioFeedback.playPhase(_intervals.first.phase);
      }
      _startClocks();
      await _startGpsTracking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modo offline — GPS em segundo plano; sincroniza ao finalizar')),
      );
    }
  }

  void _onPosition(Position pos) {
    if (!_running) return;
    if (_lastPos != null) {
      final delta = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
      // Ignora saltos GPS absurdos (>80m entre amostras).
      if (delta < 80) {
        _distance += delta;
      }
    }
    _lastPos = pos;
    _points.add({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'speedKmh': pos.speed.isNaN || pos.speed < 0 ? null : pos.speed * 3.6,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'sequenceNum': _seq++,
    });
    if (mounted) {
      setState(() {
        _gpsStatus = _points.length < 2
            ? 'GPS ok — pode apagar a tela'
            : 'GPS em 2º plano · ${_points.length} pontos';
      });
    }
  }

  Future<void> _finish({bool auto = false}) async {
    if (_finishing) return;
    _finishing = true;
    await _gpsSub?.cancel();
    _gpsSub = null;
    _clockTimer?.cancel();
    _clockTimer = null;

    if (_startedAt != null) {
      _elapsed = DateTime.now().difference(_startedAt!).inSeconds.clamp(0, 86400 * 7);
    }

    if (mounted) {
      setState(() => _running = false);
    }

    final avgSpeedKmh = _elapsed > 0 ? (_distance / 1000) / (_elapsed / 3600) : 0.0;
    final elapsedMs = _elapsed * 1000;
    final points = List<Map<String, dynamic>>.from(_points);

    try {
      if (_session != null) {
        await CardioService.instance.completeSession(
          sessionId: _session!.id,
          distanceMeters: _distance,
          avgSpeedKmh: avgSpeedKmh,
          elapsedMs: elapsedMs,
          points: points,
        );
      } else {
        final payload = {
          'clientSessionId': _clientSessionId ?? const Uuid().v4(),
          'workoutId': _workout?.id,
          'startedAt': DateTime.now()
              .subtract(Duration(seconds: _elapsed))
              .toUtc()
              .toIso8601String(),
          'completedAt': DateTime.now().toUtc().toIso8601String(),
          'distanceMeters': _distance,
          'avgSpeedKmh': avgSpeedKmh,
          'elapsedMs': elapsedMs,
          'points': points,
        };
        try {
          await AuthService.instance.post('/api/student/sync', {
            'measurements': [],
            'cardioSessions': [payload],
          });
        } catch (_) {
          await SyncService.instance.queue('cardio_session', payload);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salvo offline — sincronize depois')),
          );
          _finishing = false;
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? 'Intervalos concluídos — treino sincronizado!'
                : 'Treino sincronizado!',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      final payload = {
        'clientSessionId': _clientSessionId ?? const Uuid().v4(),
        'workoutId': _workout?.id,
        'startedAt': DateTime.now()
            .subtract(Duration(seconds: _elapsed))
            .toUtc()
            .toIso8601String(),
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'distanceMeters': _distance,
        'avgSpeedKmh': avgSpeedKmh,
        'elapsedMs': elapsedMs,
        'points': points,
      };
      await SyncService.instance.queue('cardio_session', payload);
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
      _elapsed > 0 ? (_distance / 1000) / (_elapsed / 3600) : 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _currentPhase;
    final title = _workout?.title ?? 'Corrida/caminhada livre';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino outdoor'),
        actions: [
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _workout == null
                          ? 'Sem treino prescrito — modo livre'
                          : _intervals.isEmpty
                              ? 'Treino sem intervalos'
                              : '${_intervals.length} fases · ${_workout!.type}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    if (_running) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Pode apagar a tela — o GPS continua em segundo plano',
                        style: TextStyle(color: Colors.lightGreenAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 12),
                    RouteMapView(
                      statusMessage: _running
                          ? (_gpsStatus ?? 'Buscando sinal GPS...')
                          : 'Inicie para começar o rastreio GPS',
                      points: _points
                          .map(
                            (p) => RoutePointView(
                              latitude: (p['latitude'] as num).toDouble(),
                              longitude: (p['longitude'] as num).toDouble(),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
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
                          child: _Stat(
                            'Vel. média',
                            '${_avgSpeedKmh.toStringAsFixed(1)} km/h',
                          ),
                        ),
                      ],
                    ),
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
                            color: phase.isRun ? Colors.redAccent : Colors.greenAccent,
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
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Fase ${_phaseIndex + 1} de ${_intervals.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                              ? (_gpsStatus ?? 'GPS ativo · ${_points.length} pontos')
                              : 'Inicie para começar o rastreio GPS',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const Spacer(),
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
                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: _running && !_finishing ? () => _finish() : null,
                            child: Text(_finishing ? 'Salvando...' : 'Finalizar'),
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
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
