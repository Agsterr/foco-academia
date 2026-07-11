import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/workout_service.dart';
import '../widgets/exercise_media_view.dart';
import 'login_screen.dart';

class WorkoutDayScreen extends StatefulWidget {
  const WorkoutDayScreen({super.key, required this.dayId});

  final String dayId;

  @override
  State<WorkoutDayScreen> createState() => _WorkoutDayScreenState();
}

class _WorkoutDayScreenState extends State<WorkoutDayScreen> {
  WorkoutDay? _day;
  WorkoutSession? _session;
  SessionComplete? _celebration;
  bool _loading = true;
  bool _saving = false;
  bool _showFinish = false;
  String _rating = 'BOM';
  final _commentCtrl = TextEditingController();
  int _elapsed = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    final session = _session;
    if (session == null || session.isCompleted) return;
    final start = DateTime.tryParse(session.startedAt)?.toLocal();
    if (start == null) return;
    void tick() {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(start).inSeconds.clamp(0, 86400);
      });
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final day = await WorkoutService.instance.getDay(widget.dayId);
      final session = await WorkoutService.instance.startOrResumeSession(widget.dayId);
      if (!mounted) return;
      setState(() {
        _day = day;
        _session = session;
        _loading = false;
      });
      _startTimer();
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o treino')),
      );
    }
  }

  Future<void> _toggleSet(String exerciseId, int setNumber) async {
    final session = _session;
    if (session == null || _saving) return;
    setState(() => _saving = true);
    try {
      final updated = await WorkoutService.instance.toggleSet(
        sessionId: session.id,
        exerciseId: exerciseId,
        setNumber: setNumber,
      );
      if (!mounted) return;
      setState(() => _session = updated);
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao marcar série: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null || _saving) return;
    setState(() => _saving = true);
    try {
      final result = await WorkoutService.instance.completeSession(
        sessionId: session.id,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _celebration = result;
        _session = result.session;
        _saving = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Treino')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final celebration = _celebration;
    if (celebration != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Treino concluído')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
                const SizedBox(height: 12),
                const Text(
                  'Parabéns!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  celebration.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        'Tempo total',
                        formatDuration(celebration.session.totalDurationSeconds),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        'Dias na semana',
                        '${celebration.stats.daysCompletedThisWeek}/7',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        'Sequência',
                        '${celebration.stats.currentStreak} dias',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        'Treinos totais',
                        '${celebration.stats.totalWorkoutsCompleted}',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar à ficha semanal'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    }

    final day = _day!;
    final session = _session!;
    final completedSets = session.completedSetsByExercise;
    final totalSets = day.exercises.fold<int>(0, (acc, ex) => acc + ex.setCount);
    final doneSets = session.setLogs.length;
    final progress = totalSets > 0 ? (doneSets / totalSets).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(day.muscleGroup?.isNotEmpty == true ? day.muscleGroup! : 'Treino'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekDayLabel(day.weekDay),
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
                      ),
                      if (day.notes != null && day.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(day.notes!, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Text('Cronômetro', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      Text(
                        formatDuration(_elapsed),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.amberAccent,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progresso', style: TextStyle(color: Colors.white54, fontSize: 13)),
                Text(
                  '$doneSets/$totalSets séries (${(progress * 100).round()}%)',
                  style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white12,
              ),
            ),
            const SizedBox(height: 16),
            ...day.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              final sets = exercise.setCount;
              final done = completedSets[exercise.id] ?? <int>{};
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  color: const Color(0xFF1E1E1E),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exercício ${index + 1}',
                      style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (exercise.description != null && exercise.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        exercise.description!,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text('$sets séries', style: const TextStyle(fontSize: 13)),
                        if (exercise.reps != null && exercise.reps!.isNotEmpty)
                          Text('${exercise.reps} reps', style: const TextStyle(fontSize: 13)),
                        if (exercise.duration != null && exercise.duration!.isNotEmpty)
                          Text(exercise.duration!, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    ExerciseMediaView(
                      url: exercise.videoUrl,
                      mediaType: exercise.mediaType,
                      name: exercise.name,
                    ),
                    if (exercise.variationNotes != null && exercise.variationNotes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Variação: ${exercise.variationNotes}',
                          style: const TextStyle(color: Colors.purpleAccent, fontSize: 13),
                        ),
                      ),
                    ],
                    if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        exercise.notes!,
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Marque cada série concluída:',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var n = 1; n <= sets; n++)
                          _SetChip(
                            setNumber: n,
                            done: done.contains(n),
                            elapsedMs: () {
                              for (final l in session.setLogs) {
                                if (l.exerciseId == exercise.id && l.setNumber == n) {
                                  return l.elapsedMs;
                                }
                              }
                              return null;
                            }(),
                            enabled: !_saving,
                            onTap: () => _toggleSet(exercise.id, n),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            if (!_showFinish)
              FilledButton(
                onPressed: doneSets == 0 ? null : () => setState(() => _showFinish = true),
                child: const Text('Finalizar treino'),
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                  color: const Color(0xFF1E1E1E),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Como foi o treino?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in ratingLevels)
                          ChoiceChip(
                            label: Text(ratingLabel(r)),
                            selected: _rating == r,
                            onSelected: (_) => setState(() => _rating = r),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _commentCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Comentário opcional...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: _saving ? null : _finish,
                      child: Text(_saving ? 'Salvando...' : 'Confirmar e celebrar'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetChip extends StatelessWidget {
  const _SetChip({
    required this.setNumber,
    required this.done,
    required this.onTap,
    required this.enabled,
    this.elapsedMs,
  });

  final int setNumber;
  final bool done;
  final int? elapsedMs;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: done ? Colors.green : Colors.white24),
            color: done ? Colors.green.withValues(alpha: 0.2) : Colors.black26,
          ),
          child: Column(
            children: [
              Text(
                '${done ? '✓' : '○'} Série $setNumber',
                style: TextStyle(
                  fontSize: 13,
                  color: done ? Colors.greenAccent : Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (elapsedMs != null) ...[
                const SizedBox(height: 2),
                Text(
                  '+${formatElapsed(elapsedMs)}',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
        color: const Color(0xFF1E1E1E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ],
      ),
    );
  }
}
