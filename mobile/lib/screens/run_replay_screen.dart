import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/activity_share_service.dart';
import '../services/cardio_service.dart';
import '../services/gps_ai_service.dart';
import '../services/gps_tracking_engine.dart';
import '../services/run_export_service.dart';
import '../widgets/route_map_view.dart';

/// Replay da corrida: marcador percorre a rota na velocidade real.
class RunReplayScreen extends StatefulWidget {
  const RunReplayScreen({super.key, required this.session});

  final CardioSession session;

  @override
  State<RunReplayScreen> createState() => _RunReplayScreenState();
}

class _RunReplayScreenState extends State<RunReplayScreen> {
  Timer? _timer;
  int _index = 0;
  bool _playing = false;
  double _speedFactor = 1.0;
  double _distanceAcc = 0;
  SessionAiInsights? _insights;
  bool _insightsLoading = false;
  String? _insightsError;

  List<TrackedPoint> get _points => widget.session.routePoints;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> _loadInsights() async {
    setState(() {
      _insightsLoading = true;
      _insightsError = null;
    });
    try {
      final r =
          await GpsAiService.instance.sessionInsights(widget.session.id);
      if (!mounted) return;
      setState(() {
        _insights = r;
        _insightsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _insightsLoading = false;
        _insightsError = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      return;
    }
    if (_points.length < 2) return;
    if (_index >= _points.length - 1) {
      setState(() {
        _index = 0;
        _distanceAcc = 0;
      });
    }
    setState(() => _playing = true);
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    if (!_playing || _index >= _points.length - 1) {
      setState(() => _playing = false);
      return;
    }
    final cur = _points[_index];
    final next = _points[_index + 1];
    var dtMs = next.recordedAt.difference(cur.recordedAt).inMilliseconds;
    if (dtMs < 50) dtMs = 50;
    if (dtMs > 30000) dtMs = 30000;
    final wait = (dtMs / _speedFactor).round().clamp(16, 5000);

    _timer = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      final step = _haversine(
        cur.latitude,
        cur.longitude,
        next.latitude,
        next.longitude,
      );
      setState(() {
        _index++;
        _distanceAcc += step;
      });
      _scheduleNext();
    });
  }

  TrackedPoint get _current =>
      _points.isEmpty ? _dummy : _points[_index.clamp(0, _points.length - 1)];

  static final _dummy = TrackedPoint(
    latitude: 0,
    longitude: 0,
    recordedAt: DateTime.now(),
    sequenceNum: 0,
  );

  double get _instantSpeed => _current.speedKmh ?? 0;
  double? get _instantPace =>
      _instantSpeed >= 1 ? 3600.0 / _instantSpeed : null;

  int get _elapsedSec {
    if (_points.isEmpty) return 0;
    final start = _points.first.recordedAt;
    return _current.recordedAt.difference(start).inSeconds.clamp(0, 86400);
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    double toRad(double d) => d * math.pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final mapPoints = _points
        .map((p) => RoutePointView(latitude: p.latitude, longitude: p.longitude))
        .toList();
    final title = s.workoutTitle ?? 'Treino outdoor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Replay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => ActivityShareService.instance.shareSession(s),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (_points.length < 2) return;
              if (v == 'gpx') {
                await RunExportService.instance.shareGpx(
                  points: _points,
                  title: title,
                  startedAt: s.startedAt,
                  distanceMeters: s.distanceMeters,
                );
              } else {
                await RunExportService.instance.shareTcx(
                  points: _points,
                  title: title,
                  startedAt: s.startedAt ?? DateTime.now(),
                  elapsedSec: ((s.elapsedMs ?? 0) / 1000).round(),
                  distanceMeters: s.distanceMeters ?? 0,
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'gpx', child: Text('Exportar GPX')),
              PopupMenuItem(value: 'tcx', child: Text('Exportar TCX')),
            ],
          ),
        ],
      ),
      body: _points.length < 2
          ? const Center(child: Text('Sem pontos suficientes para replay'))
          : Column(
              children: [
                RouteMapView(
                  points: mapPoints,
                  height: 280,
                  followUser: true,
                  liveLatitude: _current.latitude,
                  liveLongitude: _current.longitude,
                  statusMessage: _playing ? 'Reproduzindo…' : 'Pausado',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                      if (s.gpsQualityLabel != null)
                        Text(
                          'GPS: ${s.gpsQualityScore?.round() ?? '--'}% · ${s.gpsQualityLabel}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _m('Tempo', _fmt(_elapsedSec)),
                          _m(
                            'Distância',
                            '${(_distanceAcc / 1000).toStringAsFixed(2)} km',
                          ),
                          _m(
                            'Velocidade',
                            '${_instantSpeed.toStringAsFixed(1)} km/h',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _m(
                            'Pace',
                            GpsTrackingEngine.formatPace(_instantPace),
                          ),
                          _m(
                            'Altitude',
                            _current.altitudeMeters != null
                                ? '${_current.altitudeMeters!.toStringAsFixed(0)} m'
                                : '--',
                          ),
                          _m('kcal', '${s.caloriesKcal ?? '--'}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton.filled(
                            onPressed: _togglePlay,
                            icon: Icon(
                              _playing ? Icons.pause : Icons.play_arrow,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Velocidade'),
                          Expanded(
                            child: Slider(
                              value: _speedFactor,
                              min: 0.5,
                              max: 8,
                              divisions: 15,
                              label: '${_speedFactor.toStringAsFixed(1)}x',
                              onChanged: (v) =>
                                  setState(() => _speedFactor = v),
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: _points.length <= 1
                            ? 0
                            : _index / (_points.length - 1),
                      ),
                      const SizedBox(height: 16),
                      _buildAiSection(),
                    ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAiSection() {
    if (_insightsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }
    if (_insightsError != null) {
      return TextButton(
        onPressed: _loadInsights,
        child: const Text('Recarregar insights IA'),
      );
    }
    final r = _insights;
    if (r == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights IA',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Risco ${r.overallRiskScore.round()}% · ${r.summary}',
            style: TextStyle(
              color: r.suspiciousActivity
                  ? Colors.orangeAccent
                  : Colors.white70,
              fontSize: 13,
            ),
          ),
          if (r.trendLabel != null)
            Text(
              'Perfil: ${r.trendLabel}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          const SizedBox(height: 8),
          ...r.findings.take(4).map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• [${f.severity}] ${f.title}'
                    '${f.detail != null ? ' — ${f.detail}' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          if (r.segmentSuggestions.isNotEmpty)
            Text(
              '${r.segmentSuggestions.length} sugestão(ões) de trecho '
              '(excluir/revisar — sem inventar rota)',
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _m(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
