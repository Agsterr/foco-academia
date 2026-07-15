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
  late DateTime _focusMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusMonth = DateTime(now.year, now.month);
    _load();
  }

  void _rebuildConsistency() {
    _consistency = OutdoorConsistency.fromSessions(
      _sessions,
      focusMonth: _focusMonth,
    );
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + delta);
      _rebuildConsistency();
    });
  }

  void _jumpToYear(int year) {
    final now = DateTime.now();
    final month = year == now.year ? now.month : 12;
    setState(() {
      _focusMonth = DateTime(year, month);
      // Não passar do mês atual.
      final current = DateTime(now.year, now.month);
      if (_focusMonth.isAfter(current)) {
        _focusMonth = current;
      }
      _rebuildConsistency();
    });
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
        _rebuildConsistency();
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

  List<CardioSession> get _sessionsInFocusMonth {
    return _sessions.where((s) {
      final when = s.completedAt ?? s.startedAt;
      if (when == null) return false;
      final local = when.toLocal();
      return local.year == _focusMonth.year && local.month == _focusMonth.month;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final monthSessions = _sessionsInFocusMonth;
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
                          OutdoorCalendarCard(
                            summary: _consistency!,
                            onPreviousMonth: () => _shiftMonth(-1),
                            onNextMonth: () => _shiftMonth(1),
                            onSelectYear: _jumpToYear,
                          ),
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
                              child: Text('• $r',
                                  style: const TextStyle(fontSize: 13)),
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
                          _consistency != null
                              ? 'Treinos · ${_consistency!.monthLabel}'
                              : 'Treinos',
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
                        else if (monthSessions.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 16, bottom: 24),
                            child: Center(
                              child: Text(
                                'Nenhum treino neste mês.\n'
                                'Use as setas para ver meses e anos anteriores.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          )
                        else
                          ...monthSessions.map((s) {
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
