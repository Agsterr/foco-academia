import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key});

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> {
  StreamSubscription<Position>? _sub;
  final _points = <Map<String, dynamic>>[];
  double _distance = 0;
  int _elapsed = 0;
  Timer? _timer;
  bool _running = false;
  String? _sessionId;
  int _seq = 0;

  Future<void> _start() async {
    final perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de localização necessária')),
      );
      return;
    }

    _sessionId = const Uuid().v4();
    setState(() {
      _running = true;
      _elapsed = 0;
      _distance = 0;
      _points.clear();
      _seq = 0;
    });

    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _elapsed++));

    Position? last;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((pos) {
      if (last != null) {
        _distance += Geolocator.distanceBetween(
          last!.latitude, last!.longitude, pos.latitude, pos.longitude,
        );
      }
      last = pos;
      _points.add({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speedKmh': pos.speed * 3.6,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'sequenceNum': _seq++,
      });
      setState(() {});
    });
  }

  Future<void> _finish() async {
    await _sub?.cancel();
    _timer?.cancel();
    setState(() => _running = false);

    final payload = {
      'clientSessionId': _sessionId,
      'startedAt': DateTime.now().subtract(Duration(seconds: _elapsed)).toUtc().toIso8601String(),
      'completedAt': DateTime.now().toUtc().toIso8601String(),
      'distanceMeters': _distance,
      'avgSpeedKmh': _elapsed > 0 ? (_distance / 1000) / (_elapsed / 3600) : 0,
      'elapsedMs': _elapsed * 1000,
      'points': _points,
    };

    try {
      await AuthService.instance.post('/api/student/sync', {
        'measurements': [],
        'cardioSessions': [payload],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Treino sincronizado!')));
    } catch (_) {
      await SyncService.instance.queue('cardio_session', payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvo offline — sincronize depois')),
      );
    }
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treino outdoor')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat('Tempo', _fmt(_elapsed)),
                _Stat('Distância', '${(_distance / 1000).toStringAsFixed(2)} km'),
                _Stat('Pontos GPS', '${_points.length}'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_points.isEmpty ? 'Aguardando GPS...' : 'Rota com ${_points.length} pontos'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _running ? null : _start,
                    child: const Text('Iniciar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _running ? _finish : null,
                    child: const Text('Finalizar'),
                  ),
                ),
              ],
            ),
          ],
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
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
