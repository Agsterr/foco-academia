import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';

import '../core/ui/insets.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'cardio_screen.dart';
import 'login_screen.dart';
import 'premium_screen.dart';
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
    } on PaymentRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _starting = null);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PremiumScreen(reason: e.message)),
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
                  Row(
                    children: [
                      for (final entry in templateModalities.entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ModalityButton(
                              key: Key('modality-${entry.key}'),
                              label: entry.value,
                              modality: entry.key,
                              selected: _modality == entry.key,
                              onTap: () => setState(() => _modality = entry.key),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
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
                    for (final t in _visible) _TemplateCard(
                      template: t,
                      starting: _starting == t.key,
                      onStart: _starting != null ? null : () => _start(t),
                    ),
                ],
              ),
            ),
    );
  }
}

const _levelColors = {
  'INICIANTE': AppTheme.green,
  'INTERMEDIARIO': AppTheme.amber,
  'AVANCADO': AppTheme.red,
};

class _ModalityButton extends StatelessWidget {
  const _ModalityButton({
    super.key,
    required this.label,
    required this.modality,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String modality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = gradientForModality(modality);
    final glow = AppTheme.glowOf(gradient);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: selected ? gradient : null,
        color: selected ? null : AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Colors.transparent : glow.withValues(alpha: 0.35)),
        boxShadow: selected ? glowShadow(glow) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(iconForModality(modality), color: selected ? Colors.white : glow, size: 26),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.starting, this.onStart});

  final WorkoutTemplate template;
  final bool starting;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final gradient = gradientForModality(t.modality);
    final levelColor = _levelColors[t.level] ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(gradient: gradient),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(iconForModality(t.modality), color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.title,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(text: templateLevels[t.level] ?? t.level, color: levelColor, icon: Icons.signal_cellular_alt_rounded),
                    if (!t.isCardio)
                      _Pill(text: '${t.daysPerWeek}x por semana', color: AppTheme.cyan, icon: Icons.calendar_month_rounded),
                    _Pill(text: '~${t.sessionMinutes} min', color: AppTheme.amber, icon: Icons.timer_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.description, style: const TextStyle(color: Colors.white70, height: 1.4)),
                const SizedBox(height: 14),
                GradientButton(
                  key: Key('start-${t.key}'),
                  gradient: gradient,
                  loading: starting,
                  onPressed: onStart,
                  icon: Icons.play_arrow_rounded,
                  label: 'Começar este treino',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
