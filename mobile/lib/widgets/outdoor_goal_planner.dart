import 'package:flutter/material.dart';

import '../services/calorie_estimator.dart';
import '../services/looping_intervals.dart';
import '../services/outdoor_goal.dart';

/// Escolha de meta antes de iniciar o treino outdoor.
class OutdoorGoalPlanner extends StatefulWidget {
  const OutdoorGoalPlanner({
    super.key,
    required this.weightKg,
    required this.heightCm,
    required this.usingDefaultWeight,
    required this.hasCoachPlan,
    required this.goal,
    required this.onChanged,
  });

  final double weightKg;
  final double? heightCm;
  final bool usingDefaultWeight;
  final bool hasCoachPlan;
  final OutdoorGoal goal;
  final ValueChanged<OutdoorGoal> onChanged;

  @override
  State<OutdoorGoalPlanner> createState() => _OutdoorGoalPlannerState();
}

class _OutdoorGoalPlannerState extends State<OutdoorGoalPlanner> {
  late final TextEditingController _kmCtrl;
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _walkCtrl;
  late final TextEditingController _runCtrl;
  late final TextEditingController _minCtrl;

  @override
  void initState() {
    super.initState();
    _kmCtrl = TextEditingController(
      text: widget.goal.targetKm != null
          ? OutdoorGoal.formatKm(widget.goal.targetKm!)
          : '5',
    );
    _kcalCtrl = TextEditingController(
      text: widget.goal.targetKcal?.toString() ?? '400',
    );
    _walkCtrl = TextEditingController(text: '${widget.goal.walkMin}');
    _runCtrl = TextEditingController(text: '${widget.goal.runMin}');
    _minCtrl = TextEditingController(
      text: widget.goal.targetMinutes != null && widget.goal.targetMinutes! > 0
          ? '${widget.goal.targetMinutes}'
          : '',
    );
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _kcalCtrl.dispose();
    _walkCtrl.dispose();
    _runCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  int? get _parsedWalk =>
      int.tryParse(_walkCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
  int? get _parsedRun =>
      int.tryParse(_runCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
  double? get _parsedKm =>
      double.tryParse(_kmCtrl.text.replaceAll(',', '.').trim());

  void _setMode(OutdoorGoalMode mode) {
    var next = widget.goal.copyWith(mode: mode);
    if (mode == OutdoorGoalMode.intervals) {
      final hasKm = next.targetKm != null && next.targetKm! > 0;
      final hasMin = next.targetMinutes != null && next.targetMinutes! > 0;
      if (!hasKm && !hasMin) {
        next = next.copyWith(targetKm: 5, clearTargetMinutes: true);
        _kmCtrl.text = '5';
        _minCtrl.text = '';
      }
    }
    widget.onChanged(_withParsedTargets(next));
  }

  OutdoorGoal _withParsedTargets(OutdoorGoal base) {
    final kcal = int.tryParse(_kcalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    var next = base.copyWith(
      targetKcal: kcal,
      walkMin: _parsedWalk,
      runMin: _parsedRun,
    );
    if (base.mode == OutdoorGoalMode.distanceKm) {
      next = next.copyWith(targetKm: _parsedKm);
    }
    return next;
  }

  void _setIntervalDistance(double km) {
    _kmCtrl.text = OutdoorGoal.formatKm(km);
    _minCtrl.text = '';
    widget.onChanged(
      widget.goal.copyWith(
        mode: OutdoorGoalMode.intervals,
        targetKm: km,
        walkMin: _parsedWalk,
        runMin: _parsedRun,
        clearTargetMinutes: true,
      ),
    );
    setState(() {});
  }

  void _setIntervalMinutes(int minutes) {
    _minCtrl.text = '$minutes';
    _kmCtrl.text = '';
    widget.onChanged(
      widget.goal.copyWith(
        mode: OutdoorGoalMode.intervals,
        targetMinutes: minutes,
        walkMin: _parsedWalk,
        runMin: _parsedRun,
        clearTargetKm: true,
      ),
    );
    setState(() {});
  }

  void _onIntervalKmChanged(String value) {
    final km = double.tryParse(value.replaceAll(',', '.').trim());
    if (value.trim().isNotEmpty) {
      _minCtrl.text = '';
    }
    widget.onChanged(
      widget.goal.copyWith(
        mode: OutdoorGoalMode.intervals,
        targetKm: km != null && km > 0 ? km : null,
        walkMin: _parsedWalk,
        runMin: _parsedRun,
        clearTargetKm: km == null || km <= 0,
        clearTargetMinutes: true,
      ),
    );
    setState(() {});
  }

  void _onIntervalMinChanged(String value) {
    final minutes = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
    if (value.trim().isNotEmpty) {
      _kmCtrl.text = '';
    }
    widget.onChanged(
      widget.goal.copyWith(
        mode: OutdoorGoalMode.intervals,
        targetMinutes: minutes != null && minutes > 0 ? minutes : null,
        walkMin: _parsedWalk,
        runMin: _parsedRun,
        clearTargetKm: true,
        clearTargetMinutes: minutes == null || minutes <= 0,
      ),
    );
    setState(() {});
  }

  String get _estimateLine {
    final kcal = int.tryParse(_kcalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (kcal == null || kcal <= 0) return '';
    final km = CalorieEstimator.kmForTargetCalories(
      weightKg: widget.weightKg,
      targetKcal: kcal,
      assumedSpeedKmh: widget.goal.assumedSpeedKmh,
    );
    final weightLabel = widget.usingDefaultWeight
        ? '${widget.weightKg.toStringAsFixed(0)} kg (padrão — atualize no perfil)'
        : '${widget.weightKg.toStringAsFixed(1)} kg';
    final heightPart = widget.heightCm != null
        ? ' · ${widget.heightCm!.toStringAsFixed(0)} cm'
        : '';
    return 'Para ~$kcal kcal caminhando a ${widget.goal.assumedSpeedKmh.toStringAsFixed(0)} km/h '
        'com $weightLabel$heightPart: ≈ ${km.toStringAsFixed(1)} km';
  }

  String get _intervalPreview {
    final walk = widget.goal.walkMin.clamp(1, 30);
    final run = widget.goal.runMin.clamp(1, 30);
    final km = widget.goal.targetKm;
    final minutes = widget.goal.targetMinutes;
    if (km != null && km > 0) {
      final rounds = LoopingIntervals.estimatedRoundsForKm(
        targetKm: km,
        walkSec: walk * 60,
        runSec: run * 60,
      );
      return '$walk min caminhada + $run min corrida até ${OutdoorGoal.formatKm(km)} km · ~$rounds rodadas';
    }
    if (minutes != null && minutes > 0) {
      final rounds = LoopingIntervals.estimatedRoundsForMinutes(
        targetMin: minutes,
        walkSec: walk * 60,
        runSec: run * 60,
      );
      return '$walk min caminhada + $run min corrida por $minutes min · ~$rounds rodadas';
    }
    return '$walk min caminhada + $run min corrida — informe os km ou os minutos';
  }

  @override
  Widget build(BuildContext context) {
    final modes = <OutdoorGoalMode>[
      OutdoorGoalMode.free,
      if (widget.hasCoachPlan) OutdoorGoalMode.coach,
      OutdoorGoalMode.intervals,
      OutdoorGoalMode.distanceKm,
      OutdoorGoalMode.caloriesKcal,
    ];

    return Card(
      color: const Color(0xFF1E293B),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Seu objetivo hoje',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              widget.usingDefaultWeight
                  ? 'Peso não cadastrado — cálculos usam 70 kg. Atualize no perfil ou na balança.'
                  : 'Cálculos com ${widget.weightKg.toStringAsFixed(1)} kg'
                      '${widget.heightCm != null ? ' · ${widget.heightCm!.toStringAsFixed(0)} cm' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: widget.usingDefaultWeight
                    ? Colors.amberAccent
                    : Colors.white54,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: modes.map((mode) {
                final selected = widget.goal.mode == mode;
                final label = switch (mode) {
                  OutdoorGoalMode.free => 'Livre',
                  OutdoorGoalMode.coach => 'Coach',
                  OutdoorGoalMode.intervals => 'Intervalado',
                  OutdoorGoalMode.distanceKm => 'Distância',
                  OutdoorGoalMode.caloriesKcal => 'Calorias',
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => _setMode(mode),
                );
              }).toList(),
            ),
            if (widget.goal.mode == OutdoorGoalMode.distanceKm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _kmCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Meta em km',
                  suffixText: 'km',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) =>
                    widget.onChanged(_withParsedTargets(widget.goal)),
              ),
            ],
            if (widget.goal.mode == OutdoorGoalMode.caloriesKcal) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _kcalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Meta em calorias',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {
                  widget.onChanged(_withParsedTargets(widget.goal));
                }),
              ),
              if (_estimateLine.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _estimateLine,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.lightBlueAccent),
                ),
              ],
            ],
            if (widget.goal.mode == OutdoorGoalMode.intervals) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _walkCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Caminhada',
                        suffixText: 'min',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {
                        widget.onChanged(_withParsedTargets(widget.goal));
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _runCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Corrida',
                        suffixText: 'min',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {
                        widget.onChanged(_withParsedTargets(widget.goal));
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Até quantos km? (ou minutos)',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('interval-km-field'),
                      controller: _kmCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Distância',
                        hintText: 'ex. 7.5',
                        suffixText: 'km',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onIntervalKmChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const Key('interval-min-field'),
                      controller: _minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ou tempo',
                        hintText: 'ex. 40',
                        suffixText: 'min',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onIntervalMinChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('5 km'),
                    selected: widget.goal.targetKm == 5 &&
                        (widget.goal.targetMinutes == null ||
                            widget.goal.targetMinutes == 0),
                    onSelected: (_) => _setIntervalDistance(5),
                  ),
                  ChoiceChip(
                    label: const Text('10 km'),
                    selected: widget.goal.targetKm == 10 &&
                        (widget.goal.targetMinutes == null ||
                            widget.goal.targetMinutes == 0),
                    onSelected: (_) => _setIntervalDistance(10),
                  ),
                  ChoiceChip(
                    label: const Text('1 hora'),
                    selected: widget.goal.targetMinutes == 60 &&
                        (widget.goal.targetKm == null ||
                            widget.goal.targetKm == 0),
                    onSelected: (_) => _setIntervalMinutes(60),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _intervalPreview,
                style: const TextStyle(
                    fontSize: 12, color: Colors.lightBlueAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
