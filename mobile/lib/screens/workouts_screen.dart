import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'login_screen.dart';
import 'workout_day_screen.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  WorkoutProgram? _program;
  StudentStats? _stats;
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
      final results = await Future.wait([
        WorkoutService.instance.getActiveProgram(),
        WorkoutService.instance.getStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _program = results[0] as WorkoutProgram?;
        _stats = results[1] as StudentStats;
        _loading = false;
        if (_program == null) {
          _error = 'Nenhuma ficha semanal ativa';
        }
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

  Future<void> _openDay(WorkoutDay day) async {
    if (day.restDay) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDayScreen(dayId: day.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musculação'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _program?.title ?? 'Minha ficha semanal',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  if (_program?.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _program!.description!,
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                  if (_stats != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '${_stats!.daysCompletedThisWeek}',
                            label: 'dias esta semana',
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            value: '${_stats!.currentStreak}',
                            label: 'sequência',
                            color: Colors.greenAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            value: '${_stats!.totalWorkoutsCompleted}',
                            label: 'total',
                            color: Colors.purpleAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, style: BorderStyle.solid),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  if (_program != null)
                    ..._program!.orderedDays.map((day) {
                      final isRest = day.restDay;
                      final completed = day.completedThisWeek;
                      final inProgress = day.activeSessionId != null && !completed;
                      Color border;
                      Color? bg;
                      if (isRest) {
                        border = Colors.white12;
                        bg = Colors.white.withValues(alpha: 0.03);
                      } else if (completed) {
                        border = Colors.green.shade800;
                        bg = Colors.green.withValues(alpha: 0.12);
                      } else if (inProgress) {
                        border = Colors.amber.shade700;
                        bg = Colors.amber.withValues(alpha: 0.1);
                      } else {
                        border = Colors.white24;
                        bg = null;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: bg ?? const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: isRest ? null : () => _openDay(day),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          weekDayLabel(day.weekDay),
                                          style: const TextStyle(
                                            color: Colors.lightBlueAccent,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isRest
                                              ? 'Descanso'
                                              : (day.muscleGroup?.isNotEmpty == true
                                                  ? day.muscleGroup!
                                                  : 'Treino'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (!isRest) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            day.exercises.isEmpty
                                                ? 'Sem exercícios'
                                                : '${day.exercises.length} exercícios',
                                            style: TextStyle(
                                              color: day.exercises.isEmpty
                                                  ? Colors.amberAccent
                                                  : Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        weekDayShortLabel(day.weekDay),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (completed) ...[
                                        const SizedBox(height: 4),
                                        const Text(
                                          '✓ Feito',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ] else if (inProgress) ...[
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Em andamento',
                                          style: TextStyle(
                                            color: Colors.amberAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
