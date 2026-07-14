import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/cardio_service.dart';
import '../services/gps_ai_service.dart';
import '../services/outdoor_consistency.dart';
import '../widgets/outdoor_calendar_card.dart';
import 'login_screen.dart';
import 'run_replay_screen.dart';

/// Histórico de treinos outdoor com acesso ao Replay.
class CardioHistoryScreen extends StatefulWidget {
  const CardioHistoryScreen({super.key});

  @override
  State<CardioHistoryScreen> createState() => _CardioHistoryScreenState();
}

class _CardioHistoryScreenState extends State<CardioHistoryScreen> {
  List<CardioSession> _sessions = [];
  OutdoorConsistencySummary? _consistency;
  AthleteRecommendations? _recs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await CardioService.instance.listSessions();
      AthleteRecommendations? recs;
      try {
        recs = await GpsAiService.instance.recommendations();
      } catch (_) {
        recs = null;
      }
      if (!mounted) return;
      final completed = list.where((s) => s.completedAt != null).toList();
      setState(() {
        _sessions = completed;
        _consistency = OutdoorConsistency.fromSessions(completed);
        _recs = recs;
        _loading = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico outdoor')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if (_consistency != null) ...[
                          OutdoorCalendarCard(summary: _consistency!),
                          const SizedBox(height: 16),
                        ],
                        if (_recs != null) ...[
                          Text(
                            'Recomendações',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _recs!.evolutionSummary,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          ..._recs!.recommendations.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $r', style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                          ..._recs!.warnings.map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '⚠ $w',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          'Treinos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_sessions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                'Nenhuma corrida/caminhada concluída ainda.\n'
                                'Os dias que você treinar aparecem no calendário.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          )
                        else
                          ..._sessions.map((s) {
                            final km = ((s.distanceMeters ?? 0) / 1000)
                                .toStringAsFixed(2);
                            final when =
                                s.completedAt?.toLocal().toString() ??
                                    s.startedAt?.toLocal().toString() ??
                                    '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                title:
                                    Text(s.workoutTitle ?? 'Treino outdoor'),
                                subtitle: Text(
                                  '$km km · ${s.caloriesKcal ?? '--'} kcal'
                                  '${s.gpsQualityLabel != null ? ' · GPS ${s.gpsQualityLabel}' : ''}\n'
                                  '$when',
                                ),
                                isThreeLine: true,
                                trailing:
                                    const Icon(Icons.play_circle_outline),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RunReplayScreen(session: s),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                      ],
                    ),
            ),
    );
  }
}
