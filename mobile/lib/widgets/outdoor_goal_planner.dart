import 'package:flutter/material.dart';

import '../services/calorie_estimator.dart';
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

  @override
  void initState() {
    super.initState();
    _kmCtrl = TextEditingController(
      text: widget.goal.targetKm?.toStringAsFixed(1) ?? '5.0',
    );
    _kcalCtrl = TextEditingController(
      text: widget.goal.targetKcal?.toString() ?? '400',
    );
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _kcalCtrl.dispose();
    super.dispose();
  }

  void _setMode(OutdoorGoalMode mode) {
    final next = widget.goal.copyWith(mode: mode);
    widget.onChanged(_withParsedTargets(next));
  }

  OutdoorGoal _withParsedTargets(OutdoorGoal base) {
    final km = double.tryParse(_kmCtrl.text.replaceAll(',', '.'));
    final kcal = int.tryParse(_kcalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return base.copyWith(
      targetKm: km,
      targetKcal: kcal,
    );
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

  @override
  Widget build(BuildContext context) {
    final modes = <OutdoorGoalMode>[
      OutdoorGoalMode.free,
      if (widget.hasCoachPlan) OutdoorGoalMode.coach,
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  style: const TextStyle(fontSize: 12, color: Colors.lightBlueAccent),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
