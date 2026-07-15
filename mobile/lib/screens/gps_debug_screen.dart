import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/active_run_store.dart';
import '../services/gps_service.dart';
import '../services/location_permission_helper.dart';
import '../services/sync_service.dart';

/// Tela de telemetria GPS — apenas para desenvolvedores (kDebugMode / flavor).
class GpsDebugScreen extends StatefulWidget {
  const GpsDebugScreen({super.key});

  @override
  State<GpsDebugScreen> createState() => _GpsDebugScreenState();
}

class _GpsDebugScreenState extends State<GpsDebugScreen> {
  StreamSubscription<Position>? _sub;
  Position? _last;
  DateTime? _lastAt;
  int _fixCount = 0;
  double _distanceMeters = 0;
  Position? _prev;
  String _permission = '...';
  String _batteryOpt = '...';
  String _powerSaver = '...';
  String _batteryLevel = '...';
  String _fgs = 'parado';
  int _syncQueue = 0;
  int _localPoints = 0;
  bool _serviceEnabled = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _startStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final snap = await LocationPermissionHelper.debugPermissionSnapshot();
    final queue = await SyncService.instance.pendingCount();
    final points = await ActiveRunStore.instance.pointCount();
    if (!mounted) return;
    setState(() {
      _permission = snap['location'] ?? '...';
      _serviceEnabled = snap['serviceEnabled'] == 'true';
      _batteryOpt = snap['battery'] == 'ignored'
          ? 'ignorada (ok)'
          : (snap['battery'] == 'optimized'
              ? 'otimização ATIVA'
              : snap['battery'] ?? '...');
      _powerSaver = snap['powerSaver'] == 'on'
          ? 'LIGADA (atrapalha GPS)'
          : (snap['powerSaver'] == 'off' ? 'desligada' : snap['powerSaver'] ?? '...');
      _batteryLevel = snap['batteryLevel'] ?? '...';
      _syncQueue = queue;
      _localPoints = points;
      _fgs = _sub != null ? 'stream ativo (FGS no Android em treino)' : 'parado';
    });
  }

  Future<void> _startStream() async {
    await _sub?.cancel();
    final settings = GpsService.instance.buildSettings(
      notificationTitle: 'Debug GPS',
      notificationText: 'Telemetria de desenvolvimento',
    );
    _sub = GpsService.instance.listen(
      settings: settings,
      onPosition: (pos) {
        var delta = 0.0;
        if (_prev != null) {
          delta = Geolocator.distanceBetween(
            _prev!.latitude,
            _prev!.longitude,
            pos.latitude,
            pos.longitude,
          );
        }
        setState(() {
          if (delta >= 1.0) {
            _distanceMeters += delta;
          }
          _prev = pos;
          _last = pos;
          _lastAt = DateTime.now();
          _fixCount++;
          _fgs = 'stream ativo';
        });
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPS: $err')),
          );
        }
      },
    );
    await _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    final p = _last;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug GPS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Somente desenvolvimento — use nos testes de campo.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _row('Latitude', p?.latitude.toStringAsFixed(6) ?? '—'),
          _row('Longitude', p?.longitude.toStringAsFixed(6) ?? '—'),
          _row(
            'Accuracy',
            p == null ? '—' : '${p.accuracy.toStringAsFixed(1)} m',
          ),
          _row(
            'Velocidade',
            p == null
                ? '—'
                : '${(p.speed * 3.6).toStringAsFixed(1)} km/h',
          ),
          _row(
            'Altitude',
            p == null ? '—' : '${p.altitude.toStringAsFixed(1)} m',
          ),
          _row(
            'Heading',
            p == null ? '—' : '${p.heading.toStringAsFixed(0)}°',
          ),
          _row('Provider', 'fused (geolocator)'),
          _row('Fixes recebidos', '$_fixCount'),
          _row(
            'Distância acumulada',
            '${(_distanceMeters / 1000).toStringAsFixed(3)} km',
          ),
          _row(
            'Último timestamp',
            _lastAt?.toIso8601String() ?? '—',
          ),
          _row('Foreground / stream', _fgs),
          _row('Permissão localização', _permission),
          _row('GPS do aparelho', _serviceEnabled ? 'ligado' : 'desligado'),
          _row('Otimização de bateria', _batteryOpt),
          _row('Economia de energia', _powerSaver),
          _row('Nível da bateria', '$_batteryLevel%'),
          _row('Fila de sync', '$_syncQueue'),
          _row('Pontos SQLite (corrida ativa)', '$_localPoints'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await _sub?.cancel();
              _sub = null;
              await _startStream();
            },
            child: const Text('Reiniciar stream'),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }
}
