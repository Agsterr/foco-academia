import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';

import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'login_screen.dart';
import 'my_programs_screen.dart';
import 'templates_screen.dart';
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

  Future<void> _load({bool silent = false}) async {
    if (!silent || _program == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
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
          _error = 'Você ainda não tem um treino ativo. Monte o seu ou escolha um treino pronto.';
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

  Future<void> _openMyPrograms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyProgramsScreen()),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _openDay(WorkoutDay day) async {
    if (day.restDay) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDayScreen(dayId: day.id)),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    // Garante espaço acima da barra de navegação / botão do teclado no Android.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Musculação'),
        actions: [
          IconButton(
            key: const Key('open-my-programs'),
            tooltip: 'Meus treinos',
            onPressed: _loading ? null : _openMyPrograms,
            icon: const Icon(Icons.list_alt_rounded),
          ),
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
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                children: [
                  Text(
                    _program?.title ?? 'Minha ficha semanal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (_program?.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _program!.description!,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                    ),
                  ],
                  if (_stats != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_month_rounded,
                            value: '${_stats!.daysCompletedThisWeek}',
                            label: 'dias na semana',
                            gradient: AppTheme.oceanGradient,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            value: '${_stats!.currentStreak}',
                            label: 'sequência',
                            gradient: AppTheme.fireGradient,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.emoji_events_rounded,
                            value: '${_stats!.totalWorkoutsCompleted}',
                            label: 'treinos',
                            gradient: AppTheme.berryGradient,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const IconBadge(icon: Icons.fitness_center_rounded, gradient: AppTheme.fireGradient, size: 56),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.muted),
                            ),
                            if (_program == null) ...[
                              const SizedBox(height: 16),
                              GradientButton(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                                  );
                                  if (mounted) _load(silent: true);
                                },
                                icon: Icons.auto_awesome_rounded,
                                label: 'Ver treinos prontos',
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _openMyPrograms,
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text('Montar meu treino'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_program != null) ...[
                    const SectionHeader('Sua semana', gradient: AppTheme.fireGradient),
                    for (final (i, day) in _program!.orderedDays.indexed)
                      _DayCard(day: day, index: i, onTap: day.restDay ? null : () => _openDay(day)),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Cores que se alternam entre os dias de treino.
const _dayGradients = [
  AppTheme.fireGradient,
  AppTheme.berryGradient,
  AppTheme.oceanGradient,
  AppTheme.freshGradient,
  AppTheme.goldGradient,
  AppTheme.nightGradient,
  AppTheme.brandGradient,
];

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.index, this.onTap});

  final WorkoutDay day;
  final int index;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRest = day.restDay;
    final completed = day.completedThisWeek;
    final inProgress = day.activeSessionId != null && !completed;
    final gradient = _dayGradients[index % _dayGradients.length];
    final glow = AppTheme.glowOf(gradient);

    final (String? status, Color statusColor, IconData? statusIcon) = completed
        ? ('Feito', AppTheme.green, Icons.check_circle_rounded)
        : inProgress
            ? ('Em andamento', AppTheme.amber, Icons.play_circle_fill_rounded)
            : (null, AppTheme.muted, null);

    return Opacity(
      opacity: isRest ? 0.55 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: completed ? AppTheme.green.withValues(alpha: 0.6) : AppTheme.outline),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: isRest ? null : gradient,
                    color: isRest ? AppTheme.surfaceHigh : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: isRest ? null : glowShadow(glow, blur: 16, dy: 6),
                  ),
                  child: Center(
                    child: isRest
                        ? const Icon(Icons.self_improvement_rounded, color: AppTheme.muted)
                        : Text(
                            weekDayShortLabel(day.weekDay).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        weekDayLabel(day.weekDay),
                        style: TextStyle(color: isRest ? AppTheme.muted : glow, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isRest
                            ? 'Descanso'
                            : (day.muscleGroup?.isNotEmpty == true ? day.muscleGroup! : 'Treino'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (!isRest)
                        Text(
                          day.exercises.isEmpty ? 'Sem exercícios' : '${day.exercises.length} exercícios',
                          style: TextStyle(
                            color: day.exercises.isEmpty ? AppTheme.amber : AppTheme.muted,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                if (status != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 16),
                        const SizedBox(width: 4),
                        Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else if (!isRest)
                  Icon(Icons.play_circle_fill_rounded, color: glow, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String value;
  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final glow = AppTheme.glowOf(gradient);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [glow.withValues(alpha: 0.28), AppTheme.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: glow.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: glow, size: 22),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
