import 'package:flutter/material.dart';

import '../core/ui/insets.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'cardio_screen.dart';
import 'login_screen.dart';
import 'workouts_screen.dart';

/// Treinos prontos por modalidade (musculação, corrida, spinning, bike) e nível.
class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key, this.initialModality});

  final String? initialModality;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<WorkoutTemplate> _templates = const [];
  bool _loading = true;
  String? _error;
  late String _modality = widget.initialModality ?? 'MUSCULACAO';
  String? _level;
  String? _starting;

  static const _modalityIcons = {
    'MUSCULACAO': Icons.fitness_center_rounded,
    'CORRIDA': Icons.directions_run_rounded,
    'SPINNING': Icons.pedal_bike_rounded,
    'BIKE': Icons.directions_bike_rounded,
  };

  static const _levelColors = {
    'INICIANTE': Colors.greenAccent,
    'INTERMEDIARIO': Colors.amberAccent,
    'AVANCADO': Colors.redAccent,
  };

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
      final list = await WorkoutService.instance.listTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list;
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
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<WorkoutTemplate> get _visible => _templates
      .where((t) => t.modality == _modality && (_level == null || t.level == _level))
      .toList();

  Future<void> _start(WorkoutTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(template.title),
        content: Text(
          template.isCardio
              ? 'Este treino vira o seu treino outdoor ativo, com as fases de corrida e caminhada '
                  'avisadas pelo app.'
              : 'Esta ficha vira a sua ficha ativa em Musculação. Suas outras fichas continuam '
                  'salvas em "Meus treinos".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Começar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _starting = template.key);
    try {
      final kind = await WorkoutService.instance.startTemplate(template.key);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => kind == 'CARDIO' ? const CardioScreen() : const WorkoutsScreen(),
        ),
      );
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _starting = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Treinos prontos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: scrollablePadding(context),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in templateModalities.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              key: Key('modality-${entry.key}'),
                              avatar: Icon(_modalityIcons[entry.key], size: 18),
                              label: Text(entry.value),
                              selected: _modality == entry.key,
                              onSelected: (_) => setState(() => _modality = entry.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos os níveis'),
                        selected: _level == null,
                        onSelected: (_) => setState(() => _level = null),
                      ),
                      for (final entry in templateLevels.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _level == entry.key,
                          onSelected: (_) => setState(() => _level = entry.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    )
                  else
                    for (final t in _visible)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (_levelColors[t.level] ?? Colors.white).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      templateLevels[t.level] ?? t.level,
                                      style: TextStyle(
                                        color: _levelColors[t.level],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    t.isCardio
                                        ? '~${t.sessionMinutes} min'
                                        : '${t.daysPerWeek}x/semana · ~${t.sessionMinutes} min',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(t.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text(t.description, style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  key: Key('start-${t.key}'),
                                  onPressed: _starting != null ? null : () => _start(t),
                                  icon: _starting == t.key
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Começar este treino'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
    );
  }
}
