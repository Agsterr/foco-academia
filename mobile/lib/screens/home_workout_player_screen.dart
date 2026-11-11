import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';
import '../data/home_workouts.dart';
import '../services/calorie_estimator.dart';
import '../services/cardio_feedback.dart';
import '../services/home_workout_progress.dart';
import '../services/profile_service.dart';
import '../widgets/exercise_figure.dart';

enum _Phase { getReady, work, rest, done }

/// Executa um treino em casa: contagem regressiva de cada exercício, descanso, voz e bipes.
class HomeWorkoutPlayerScreen extends StatefulWidget {
  const HomeWorkoutPlayerScreen({
    super.key,
    required this.workout,
    this.enableAudio = true,
    this.enableWakelock = true,
    this.getReadySeconds = 5,
    this.weightKg,
  });

  final HomeWorkout workout;

  /// Desligado nos testes (plugins de áudio/tela).
  final bool enableAudio;
  final bool enableWakelock;
  final int getReadySeconds;

  /// Peso para calcular as calorias; sem ele usa o do perfil e, na falta, 70 kg.
  final double? weightKg;

  @override
  State<HomeWorkoutPlayerScreen> createState() =>
      _HomeWorkoutPlayerScreenState();
}

class _HomeWorkoutPlayerScreenState extends State<HomeWorkoutPlayerScreen> {
  Timer? _timer;
  _Phase _phase = _Phase.getReady;
  int _index = 0;
  late int _remaining;
  bool _paused = false;
  bool _sound = true;

  int _doneSteps = 0;
  int _actualWork = 0;
  int _actualRest = 0;
  double? _weightKg;

  HomeWorkoutResult? _result;
  bool _saving = false;

  HomeWorkout get _w => widget.workout;
  HomeStep get _step => _w.steps[_index];
  HomeLevel get _level => _w.level;

  @override
  void initState() {
    super.initState();
    _remaining = widget.getReadySeconds;
    _weightKg = widget.weightKg;
    if (widget.enableWakelock) {
      unawaited(_guard(() => WakelockPlus.enable()));
    }
    if (_weightKg == null) unawaited(_loadWeight());
    _cue(() => CardioFeedback.say('Prepare-se. ${_step.exercise.name}'));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.enableWakelock) {
      unawaited(_guard(() => WakelockPlus.disable()));
    }
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }

  Future<void> _loadWeight() async {
    try {
      final profile = await ProfileService.instance
          .getProfile()
          .timeout(const Duration(seconds: 4));
      _weightKg = profile.currentWeightKg;
    } catch (_) {
      // Sem internet: usa o peso padrão.
    }
  }

  void _cue(Future<void> Function() fn) {
    if (!widget.enableAudio || !_sound) return;
    unawaited(_guard(fn));
  }

  void _haptic(Future<void> Function() fn) => unawaited(_guard(fn));

  void _tick() {
    if (_paused || _phase == _Phase.done || !mounted) return;
    setState(() {
      _remaining--;
      if (_phase == _Phase.work) _actualWork++;
      if (_phase == _Phase.rest) _actualRest++;
    });
    if (_remaining > 0 && _remaining <= 3) {
      _haptic(HapticFeedback.selectionClick);
      _cue(() => CardioFeedback.beep());
    }
    if (_remaining <= 0) _advance();
  }

  void _startWork() {
    _phase = _Phase.work;
    _remaining = _step.workSeconds;
    _haptic(HapticFeedback.heavyImpact);
    _cue(() => CardioFeedback.beep(frequencyHz: 1100, durationMs: 320));
  }

  void _startRest() {
    final next = _w.steps[_index + 1].exercise;
    _phase = _Phase.rest;
    _remaining = _step.restSeconds;
    _haptic(HapticFeedback.mediumImpact);
    _cue(() => CardioFeedback.say('Descanse. A seguir, ${next.name}'));
  }

  /// Avança para a próxima fase (também usado para pular).
  void _advance() {
    setState(() {
      switch (_phase) {
        case _Phase.getReady:
          _startWork();
        case _Phase.work:
          // Conta o exercício se foi feito pelo menos metade do tempo.
          if (_step.workSeconds - _remaining >= _step.workSeconds / 2) {
            _doneSteps++;
          }
          if (_index >= _w.steps.length - 1) {
            _finish();
          } else if (_step.restSeconds > 0) {
            _startRest();
          } else {
            _index++;
            _startWork();
          }
        case _Phase.rest:
          _index++;
          _startWork();
        case _Phase.done:
          break;
      }
    });
  }

  void _previous() {
    if (_phase == _Phase.done) return;
    setState(() {
      final restarting =
          _phase == _Phase.work && _step.workSeconds - _remaining > 3;
      if (_phase == _Phase.rest || restarting || _index == 0) {
        _startWork();
      } else {
        _index--;
        _startWork();
      }
    });
  }

  void _finish() {
    _phase = _Phase.done;
    _remaining = 0;
    _cue(CardioFeedback.playFinish);
    _haptic(HapticFeedback.vibrate);
    unawaited(_save());
  }

  Future<void> _save() async {
    if (_saving || _result != null) return;
    _saving = true;
    final weight = CalorieEstimator.resolveWeight(_weightKg);
    final seconds = _actualWork + _actualRest;
    final log = HomeWorkoutLog(
      workoutId: _w.id,
      title: _w.title,
      level: _level.name,
      at: DateTime.now(),
      seconds: seconds,
      kcal: kcalFor(_level, _actualWork, _actualRest, weight),
      exercises: _doneSteps,
      xp: homeWorkoutXp(_level, _doneSteps, seconds),
    );
    HomeWorkoutResult? result;
    try {
      result = await HomeWorkoutProgress.instance.record(log);
    } catch (_) {
      // Falha ao gravar: ainda mostra o resumo, só não entra no histórico.
    }
    if (!mounted) return;
    setState(() {
      _result = result ?? _unsavedResult(log);
      _saving = false;
    });
  }

  HomeWorkoutResult _unsavedResult(HomeWorkoutLog log) {
    final stats = HomeWorkoutStats(const []);
    return HomeWorkoutResult(
        log: log,
        before: stats,
        after: stats,
        newBadges: const [],
        leveledUp: false);
  }

  Future<void> _confirmExit() async {
    if (_phase == _Phase.done) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() => _paused = true);
    final canSave = _doneSteps > 0;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do treino?'),
        content: Text(
          canSave
              ? 'Você já fez $_doneSteps exercício(s). Pode encerrar agora e salvar o que fez, ou sair sem salvar.'
              : 'Você ainda não concluiu nenhum exercício. O treino não será salvo.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'continue'),
              child: const Text('Continuar')),
          if (canSave)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'save'),
                child: const Text('Encerrar e salvar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'leave'),
            child: const Text('Sair', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'save':
        setState(_finish);
      case 'leave':
        Navigator.of(context).pop(false);
      default:
        setState(() => _paused = false);
    }
  }

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: GlowBackground(
          child: SafeArea(
              child: _phase == _Phase.done ? _buildSummary() : _buildPlayer()),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final isRest = _phase == _Phase.rest;
    final isReady = _phase == _Phase.getReady;
    // Em descanso e na contagem inicial mostra o exercício que vem a seguir.
    final shown = isRest ? _w.steps[_index + 1].exercise : _step.exercise;
    final total = isReady
        ? widget.getReadySeconds
        : isRest
            ? _step.restSeconds
            : _step.workSeconds;
    final accent =
        isRest ? AppTheme.teal : (isReady ? AppTheme.amber : shown.color);
    final label = isReady ? 'PREPARE-SE' : (isRest ? 'DESCANSO' : 'EXERCÍCIO');
    final stepNumber =
        (isRest ? _index + 2 : _index + 1).clamp(1, _w.steps.length);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                key: const Key('hw-close'),
                tooltip: 'Sair',
                onPressed: _confirmExit,
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  _w.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: const Key('hw-sound'),
                tooltip: _sound ? 'Desligar voz e bipes' : 'Ligar voz e bipes',
                onPressed: () => setState(() => _sound = !_sound),
                icon: Icon(_sound
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Column(
            children: [
              _StepsBar(
                  total: _w.steps.length,
                  current: stepNumber - 1,
                  color: _level.color),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Exercício $stepNumber de ${_w.steps.length}',
                      style:
                          const TextStyle(color: AppTheme.muted, fontSize: 12)),
                  Text('${_level.label} · ${_w.focus}',
                      style:
                          const TextStyle(color: AppTheme.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final figureSize = math.min(
                  math.min(box.maxWidth - 40, box.maxHeight * 0.5), 320.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight - 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: accent.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          label,
                          key: const Key('hw-phase'),
                          style: TextStyle(
                              color: accent,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ExerciseFigure(
                        key: ValueKey('${shown.id}-$_phase'),
                        animation: shown.figure,
                        color: accent,
                        size: figureSize,
                        animate: !_paused,
                      ),
                      Text(
                        shown.name,
                        key: const Key('hw-exercise-name'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1),
                      ),
                      const SizedBox(height: 4),
                      Text(shown.muscle,
                          style: TextStyle(
                              color: accent, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        shown.how,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 13, height: 1.35),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundButton(
                  key: const Key('hw-prev'),
                  icon: Icons.skip_previous_rounded,
                  onTap: _previous,
                  tooltip: 'Anterior'),
              _TimerRing(
                seconds: _remaining,
                total: total,
                color: accent,
                label: _clock(_remaining),
                paused: _paused,
                onTap: () => setState(() => _paused = !_paused),
              ),
              _RoundButton(
                  key: const Key('hw-skip'),
                  icon: Icons.skip_next_rounded,
                  onTap: _advance,
                  tooltip: 'Pular'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final result = _result;
    final log = result?.log;
    if (result == null || log == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final level = result.after.playerLevel;
    final streak = result.after.streak;
    final partial = log.exercises < _w.steps.length;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            children: [
              HeroCard(
                gradient: _level.gradient,
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events_rounded,
                        color: Colors.white, size: 56),
                    const SizedBox(height: 8),
                    Text(
                      partial ? 'Bom trabalho!' : 'Treino concluído!',
                      key: const Key('hw-summary-title'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _w.title,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: _SummaryStat(
                                icon: Icons.local_fire_department_rounded,
                                value: '${log.kcal}',
                                label: 'kcal')),
                        Expanded(
                            child: _SummaryStat(
                                icon: Icons.timer_rounded,
                                value: _clock(log.seconds),
                                label: 'tempo')),
                        Expanded(
                            child: _SummaryStat(
                                icon: Icons.fitness_center_rounded,
                                value: '${log.exercises}',
                                label: 'exercícios')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt_rounded, color: AppTheme.amber),
                        const SizedBox(width: 8),
                        Text('+${log.xp} XP',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nível ${level.level} · ${level.title}',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppTheme.muted, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: level.progress,
                        minHeight: 10,
                        backgroundColor: AppTheme.outline,
                        valueColor:
                            const AlwaysStoppedAnimation(AppTheme.amber),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${level.xpInto}/${level.xpNeeded} XP para o próximo nível',
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 12)),
                    if (result.leveledUp) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Subiu de nível! Agora você é ${level.title}.',
                        key: const Key('hw-level-up'),
                        style: const TextStyle(
                            color: AppTheme.amber, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Panel(
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppTheme.orange, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        streak <= 1
                            ? 'Sequência de $streak dia. Volte amanhã!'
                            : 'Sequência de $streak dias seguidos!',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              if (result.newBadges.isNotEmpty) ...[
                const SectionHeader('Nova conquista',
                    gradient: AppTheme.goldGradient),
                for (final b in result.newBadges)
                  _Panel(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: b.color.withValues(alpha: 0.2),
                              shape: BoxShape.circle),
                          child: Icon(b.icon, color: b.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(b.description,
                                  style: const TextStyle(
                                      color: AppTheme.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Calorias estimadas pelo seu peso e pela intensidade do treino.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: GradientButton(
            key: const Key('hw-finish'),
            label: 'Concluir',
            icon: Icons.check_rounded,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
      ],
    );
  }
}

class _StepsBar extends StatelessWidget {
  const _StepsBar(
      {required this.total, required this.current, required this.color});

  final int total;
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: i < current
                    ? color
                    : (i == current
                        ? color.withValues(alpha: 0.6)
                        : AppTheme.outline),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.seconds,
    required this.total,
    required this.color,
    required this.label,
    required this.paused,
    required this.onTap,
  });

  final int seconds;
  final int total;
  final Color color;
  final String label;
  final bool paused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = total <= 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
    return GestureDetector(
      key: const Key('hw-timer'),
      onTap: onTap,
      child: SizedBox(
        width: 132,
        height: 132,
        child: CustomPaint(
          painter: _RingPainter(fraction: fraction, color: color),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paused ? 'PAUSADO' : label,
                  key: const Key('hw-time'),
                  style: TextStyle(
                    fontSize: paused ? 15 : 32,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.075;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(
      r,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = AppTheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      r,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {super.key,
      required this.icon,
      required this.onTap,
      required this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceHigh,
      shape: const CircleBorder(side: BorderSide(color: AppTheme.outline)),
      child: IconButton(
        tooltip: tooltip,
        iconSize: 32,
        padding: const EdgeInsets.all(14),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.margin});

  final Widget child;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: child,
    );
  }
}
