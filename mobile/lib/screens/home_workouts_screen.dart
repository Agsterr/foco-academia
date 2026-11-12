import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';
import '../data/home_workouts.dart';
import '../services/calorie_estimator.dart';
import '../services/home_workout_progress.dart';
import '../services/profile_service.dart';
import '../widgets/exercise_figure.dart';
import 'home_workout_player_screen.dart';

/// "Treino em casa": treinos sem equipamento em quatro intensidades, com exercícios desenhados,
/// tempo de cada um, calorias e conquistas.
class HomeWorkoutsScreen extends StatefulWidget {
  const HomeWorkoutsScreen({super.key});

  @override
  State<HomeWorkoutsScreen> createState() => _HomeWorkoutsScreenState();
}

class _HomeWorkoutsScreenState extends State<HomeWorkoutsScreen> {
  HomeWorkoutStats _stats = HomeWorkoutStats(const []);
  HomeLevel? _filter;
  double _weightKg = CalorieEstimator.defaultWeightKg;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadWeight();
  }

  Future<void> _reload() async {
    final stats = await HomeWorkoutProgress.instance.loadStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _loadWeight() async {
    try {
      final p = await ProfileService.instance.getProfile().timeout(const Duration(seconds: 4));
      if (mounted) setState(() => _weightKg = CalorieEstimator.resolveWeight(p.currentWeightKg));
    } catch (_) {
      // Sem internet: estima com o peso padrão.
    }
  }

  Future<void> _open(HomeWorkout w) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeWorkoutDetailScreen(workout: w, weightKg: _weightKg)),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final workouts = [for (final w in homeWorkouts) if (_filter == null || w.level == _filter) w];
    return Scaffold(
      appBar: AppBar(title: const Text('Treino em casa')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottom),
          children: [
            _ProgressCard(stats: _stats),
            const SectionHeader('Escolha a intensidade'),
            Wrap(
              runSpacing: 8,
              children: [
                _LevelChip(label: 'Todos', color: AppTheme.brand, selected: _filter == null, onTap: () => setState(() => _filter = null)),
                for (final l in HomeLevel.values)
                  _LevelChip(
                    key: Key('hw-filter-${l.name}'),
                    label: l.label,
                    color: l.color,
                    icon: l.icon,
                    selected: _filter == l,
                    onTap: () => setState(() => _filter = l),
                  ),
              ],
            ),
            if (_filter != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 2),
                child: Text(_filter!.blurb, style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
              ),
            const SizedBox(height: 12),
            for (final w in workouts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WorkoutCard(workout: w, kcal: w.estimateKcal(_weightKg), onTap: () => _open(w)),
              ),
            const SectionHeader('Conquistas', gradient: AppTheme.goldGradient),
            _BadgesGrid(earned: _stats.earnedBadgeIds),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.stats});

  final HomeWorkoutStats stats;

  @override
  Widget build(BuildContext context) {
    final level = stats.playerLevel;
    final week = stats.workoutsThisWeek;
    final kcal7 = stats.kcalLast7Days;
    final maxKcal = kcal7.fold<int>(0, (a, b) => b > a ? b : a);
    const dayNames = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final today = DateTime.now();
    return HeroCard(
      key: const Key('hw-progress-card'),
      gradient: AppTheme.brandGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Text('${level.level}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: level.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('${level.xpInto}/${level.xpNeeded} XP', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Stat(icon: Icons.local_fire_department_rounded, value: '${stats.streak}', label: 'dias seguidos')),
              Expanded(child: _Stat(icon: Icons.bolt_rounded, value: '${stats.totalKcal}', label: 'kcal no total')),
              Expanded(child: _Stat(icon: Icons.fitness_center_rounded, value: '${stats.totalExercises}', label: 'exercícios')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text('Meta da semana: $week/${HomeWorkoutStats.weeklyGoal}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              for (var i = 0; i < HomeWorkoutStats.weeklyGoal; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    i < week ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: Colors.white.withValues(alpha: i < week ? 1 : 0.6),
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 62,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: maxKcal == 0 ? 4 : (4 + 36 * kcal7[i] / maxKcal),
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: kcal7[i] > 0 ? 0.95 : 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dayNames[DateTime(today.year, today.month, today.day - (6 - i)).weekday - 1],
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text('Calorias dos últimos 7 dias', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.15)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : AppTheme.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? color : AppTheme.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? Colors.white : color),
                  const SizedBox(width: 6),
                ],
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout, required this.kcal, required this.onTap});

  final HomeWorkout workout;
  final int kcal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = workout.level;
    final glow = level.color;
    final first = workout.steps.first.exercise;
    return Container(
      key: Key('hw-card-${workout.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [glow.withValues(alpha: 0.25), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: glow.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                ExerciseFigure(animation: first.figure, color: glow, size: 92, animate: false, showFloor: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(gradient: level.gradient, borderRadius: BorderRadius.circular(10)),
                        child: Text(level.label.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      ),
                      const SizedBox(height: 6),
                      Text(workout.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(workout.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          _Meta(icon: Icons.timer_rounded, text: '${workout.minutes} min'),
                          _Meta(icon: Icons.local_fire_department_rounded, text: '~$kcal kcal'),
                          _Meta(icon: Icons.fitness_center_rounded, text: '${workout.steps.length} exerc.'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.muted),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BadgesGrid extends StatelessWidget {
  const _BadgesGrid({required this.earned});

  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final b in homeBadges)
          Builder(builder: (context) {
            final has = earned.contains(b.id);
            final width = (MediaQuery.sizeOf(context).width - 32 - 20) / 3;
            return Tooltip(
              message: b.description,
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                key: Key('hw-badge-${b.id}'),
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: has ? b.color.withValues(alpha: 0.7) : AppTheme.outline),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: has ? b.color.withValues(alpha: 0.2) : AppTheme.surfaceHigh,
                      ),
                      child: Icon(has ? b.icon : Icons.lock_rounded, color: has ? b.color : Colors.white30, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: has ? Colors.white : Colors.white38),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Prévia do treino: lista os exercícios com o desenho, o tempo de cada um e o descanso.
class HomeWorkoutDetailScreen extends StatelessWidget {
  const HomeWorkoutDetailScreen({super.key, required this.workout, this.weightKg = CalorieEstimator.defaultWeightKg});

  final HomeWorkout workout;
  final double weightKg;

  Future<void> _start(BuildContext context) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HomeWorkoutPlayerScreen(workout: workout, weightKg: weightKg)),
    );
    if (done == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final level = workout.level;
    return Scaffold(
      appBar: AppBar(title: Text(workout.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  HeroCard(
                    gradient: level.gradient,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(level.icon, color: Colors.white),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text('Nível ${level.label} · ${workout.focus}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(workout.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _Stat(icon: Icons.timer_rounded, value: '${workout.minutes}', label: 'minutos')),
                            Expanded(
                              child: _Stat(icon: Icons.local_fire_department_rounded, value: '~${workout.estimateKcal(weightKg)}', label: 'kcal'),
                            ),
                            Expanded(child: _Stat(icon: Icons.fitness_center_rounded, value: '${workout.steps.length}', label: 'exercícios')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader('Exercícios'),
                  for (var i = 0; i < workout.steps.length; i++) _StepTile(index: i + 1, step: workout.steps[i], color: level.color),
                  const SizedBox(height: 4),
                  const Text(
                    'Sem equipamento. Use um tapete ou um piso firme e pare se sentir dor. '
                    'Calorias estimadas pelo seu peso e pela intensidade.',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + (bottom > 0 ? 0 : 4)),
              child: GradientButton(
                key: const Key('hw-start'),
                label: 'Começar treino',
                icon: Icons.play_arrow_rounded,
                gradient: level.gradient,
                onPressed: () => _start(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.step, required this.color});

  final int index;
  final HomeStep step;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final e = step.exercise;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          ExerciseFigure(animation: e.figure, color: e.color, size: 72, animate: false, showFloor: false),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$index. ${e.name}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(e.muscle, style: TextStyle(color: e.color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${step.workSeconds}s', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (step.restSeconds > 0)
                Text('+${step.restSeconds}s descanso', style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
