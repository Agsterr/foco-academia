import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';

import '../services/auth_service.dart';
import '../services/calorie_estimator.dart';
import '../services/calories_service.dart';
import '../services/workout_service.dart';
import '../widgets/exercise_media_view.dart';
import 'login_screen.dart';
import '../core/ui/error_text.dart';

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
  String _intensity = 'MODERADA';
  double _weightKg = CalorieEstimator.defaultWeightKg;
  final _commentCtrl = TextEditingController();
  int _elapsed = 0;
  Timer? _timer;

  static const _intensities = {
    'LEVE': 'Leve',
    'MODERADA': 'Moderada',
    'PESADA': 'Pesada',
    'MUITO_INTENSA': 'Muito intensa',
  };

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
        _elapsed = DateTime.now().difference(start).inSeconds.clamp(0, 3 * 3600);
      });
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final day = await WorkoutService.instance.getDay(widget.dayId);
      WorkoutSession? session;
      if (day.activeSessionId != null) {
        session = await WorkoutService.instance.startOrResumeSession(widget.dayId);
      }
      try {
        _weightKg = await CaloriesService.instance.loadAthleteWeightKg();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _day = day;
        _session = session;
        _loading = false;
      });
      if (session != null) _startTimer();
    } on SessionExpiredException {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o treino')),
      );
    }
  }

  Future<void> _startSession() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final session = await WorkoutService.instance.startOrResumeSession(widget.dayId);
      if (!mounted) return;
      setState(() {
        _session = session;
        _saving = false;
      });
      _startTimer();
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
        SnackBar(content: Text('Não foi possível iniciar: ${errorText(e)}')),
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
        SnackBar(content: Text('Erro ao marcar série: ${errorText(e)}')),
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
        intensity: _intensity,
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
        SnackBar(content: Text('Erro ao finalizar: ${errorText(e)}')),
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
                const Center(child: IconBadge(icon: Icons.emoji_events_rounded, gradient: AppTheme.goldGradient, size: 96)),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
                const Text(
                  'Parabéns!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.lime),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStat(
                        'Calorias*',
                        '${celebration.session.caloriesKcal ?? 0} kcal',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStat(
                        'Hoje',
                        '${celebration.stats.caloriesToday} kcal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '*Estimativa baseada em MET, peso e intensidade',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Voltar à ficha semanal'),
                ),
                SizedBox(height: 8 + MediaQuery.viewPaddingOf(context).bottom),
              ],
            ),
          ),
        ),
      );
    }

    final day = _day!;
    final session = _session;
    final started = session != null && !session.isCompleted;
    final completedSets = session?.completedSetsByExercise ?? <String, Set<int>>{};
    final totalSets = day.exercises.fold<int>(0, (acc, ex) => acc + ex.setCount);
    final doneSets = session?.setLogs.length ?? 0;
    final progress = totalSets > 0 ? (doneSets / totalSets).clamp(0.0, 1.0) : 0.0;
    final hasExercises = day.exercises.isNotEmpty;
    final canFinish = started && (!hasExercises || doneSets > 0);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(day.muscleGroup?.isNotEmpty == true ? day.muscleGroup! : 'Treino'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
          children: [
            HeroCard(
              gradient: AppTheme.fireGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weekDayLabel(day.weekDay).toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                            Text(
                              formatDuration(_elapsed),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (day.notes != null && day.notes!.isNotEmpty)
                              Text(day.notes!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Colors.white),
                            Text(
                              started
                                  ? '${CalorieEstimator.strengthKcal(weightKg: _weightKg, durationSeconds: _elapsed, intensity: _intensity)}'
                                  : '0',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                            ),
                            const Text('kcal*', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progresso', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        '$doneSets/$totalSets séries · ${(progress * 100).round()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!hasExercises)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.amber.withValues(alpha: 0.6)),
                  color: AppTheme.amber.withValues(alpha: 0.12),
                ),
                child: const Text(
                  'Este dia não tem exercícios cadastrados. '
                  'Você pode finalizar o treino para liberar a ficha, '
                  'ou peça ao instrutor para completar a ficha.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 13),
                ),
              ),
            ...day.exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              final sets = exercise.setCount;
              final done = completedSets[exercise.id] ?? <int>{};
              final allDone = sets > 0 && done.length >= sets;
              final gradient = _exerciseGradients[index % _exerciseGradients.length];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: allDone ? AppTheme.green.withValues(alpha: 0.7) : AppTheme.outline),
                  color: AppTheme.surface,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: allDone ? AppTheme.freshGradient : gradient,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Center(
                            child: allDone
                                ? const Icon(Icons.check_rounded, color: Colors.white)
                                : Text('${index + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
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
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoPill(icon: Icons.layers_rounded, text: '$sets séries', color: AppTheme.glowOf(gradient)),
                        if (exercise.reps != null && exercise.reps!.isNotEmpty)
                          _InfoPill(icon: Icons.repeat_rounded, text: '${exercise.reps} reps', color: AppTheme.cyan),
                        if (exercise.duration != null && exercise.duration!.isNotEmpty)
                          _InfoPill(icon: Icons.timer_rounded, text: exercise.duration!, color: AppTheme.amber),
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
                          color: AppTheme.violet.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Variação: ${exercise.variationNotes}',
                          style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 13),
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
                              if (session == null) return null;
                              for (final l in session.setLogs) {
                                if (l.exerciseId == exercise.id && l.setNumber == n) {
                                  return l.elapsedMs;
                                }
                              }
                              return null;
                            }(),
                            enabled: !_saving && started,
                            onTap: () => _toggleSet(exercise.id, n),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            if (!started)
              GradientButton(
                onPressed: _saving ? null : _startSession,
                loading: _saving,
                icon: Icons.play_arrow_rounded,
                gradient: AppTheme.fireGradient,
                label: 'Iniciar treino',
              )
            else if (!_showFinish)
              GradientButton(
                onPressed: canFinish ? () => setState(() => _showFinish = true) : null,
                icon: Icons.flag_rounded,
                gradient: AppTheme.freshGradient,
                label: hasExercises ? 'Finalizar treino' : 'Finalizar mesmo sem exercícios',
              )
            else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.outline),
                  color: AppTheme.surface,
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
                    const SizedBox(height: 14),
                    const Text(
                      'Intensidade (estimativa de calorias)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in _intensities.entries)
                          ChoiceChip(
                            label: Text(entry.value),
                            selected: _intensity == entry.key,
                            onSelected: (_) => setState(() => _intensity = entry.key),
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
                    GradientButton(
                      gradient: AppTheme.freshGradient,
                      icon: Icons.celebration_rounded,
                      onPressed: _saving ? null : _finish,
                      loading: _saving,
                      label: 'Confirmar e celebrar',
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
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 76),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: done ? AppTheme.freshGradient : null,
            border: done ? null : Border.all(color: AppTheme.outline),
            color: done ? null : AppTheme.surfaceHigh,
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: done ? const Color(0xFF052E1B) : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Série $setNumber',
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? const Color(0xFF052E1B) : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (elapsedMs != null) ...[
                const SizedBox(height: 2),
                Text(
                  '+${formatElapsed(elapsedMs)}',
                  style: TextStyle(fontSize: 10, color: done ? const Color(0xFF064E2B) : Colors.white38),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _exerciseGradients = [
  AppTheme.fireGradient,
  AppTheme.berryGradient,
  AppTheme.oceanGradient,
  AppTheme.goldGradient,
  AppTheme.nightGradient,
];

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
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
        border: Border.all(color: AppTheme.outline),
        color: AppTheme.surface,
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
