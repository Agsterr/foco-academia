import 'package:flutter/material.dart';

import '../core/ui/insets.dart';
import '../data/exercise_library.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'premium_screen.dart';

/// Montagem de ficha própria: dias da semana, exercícios da biblioteca (ou digitados), séries e repetições.
class ProgramEditorScreen extends StatefulWidget {
  const ProgramEditorScreen({super.key, this.program, this.studentId, this.studentName});

  /// Ficha própria a editar; nulo para criar uma nova.
  final WorkoutProgram? program;

  /// Instrutor montando a ficha de um aluno (vira a ficha ativa dele).
  final String? studentId;
  final String? studentName;

  @override
  State<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends State<ProgramEditorScreen> {
  late final TextEditingController _title;
  late final List<DayDraft> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final program = widget.program;
    final defaultTitle = widget.studentName != null ? 'Treino de ${widget.studentName!.split(' ').first}' : 'Meu treino';
    _title = TextEditingController(text: program?.title ?? defaultTitle);
    final byWeekDay = {for (final d in program?.days ?? const <WorkoutDay>[]) d.weekDay: d};
    _days = [
      for (final wd in weekDayOrder)
        DayDraft(
          weekDay: wd,
          title: (byWeekDay[wd]?.restDay ?? true) ? '' : (byWeekDay[wd]?.muscleGroup ?? ''),
          exercises: [
            if (!(byWeekDay[wd]?.restDay ?? true))
              for (final e in byWeekDay[wd]!.exercises)
                ExerciseDraft(
                  name: e.name,
                  sets: e.sets ?? 1,
                  reps: e.reps ?? '',
                  duration: e.reps == null ? e.duration : null,
                  description: e.description,
                ),
          ],
        ),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _addExercise(DayDraft day) async {
    final picked = await showModalBottomSheet<ExerciseDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ExercisePicker(),
    );
    if (picked != null) setState(() => day.exercises.add(picked));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Dê um nome para o treino.');
      return;
    }
    if (_days.every((d) => d.isRest)) {
      _snack('Adicione exercícios em pelo menos um dia.');
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.studentId != null) {
        await WorkoutService.instance.createProgramForStudent(widget.studentId!, title, _days);
      } else if (widget.program == null) {
        await WorkoutService.instance.createProgram(title, _days);
      } else {
        await WorkoutService.instance.updateProgram(widget.program!.id, title, _days);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PaymentRequiredException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PremiumScreen(reason: e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName != null
            ? 'Ficha de ${widget.studentName!.split(' ').first}'
            : widget.program == null
                ? 'Montar treino'
                : 'Editar treino'),
        actions: [
          TextButton(
            key: const Key('save-program'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar'),
          ),
        ],
      ),
      body: ListView(
        padding: scrollablePadding(context),
        children: [
          TextField(
            key: const Key('program-title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome do treino'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Dia sem exercícios fica como descanso.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final day in _days) _dayCard(day),
        ],
      ),
    );
  }

  Widget _dayCard(DayDraft day) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    weekDayLabel(day.weekDay),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                if (day.isRest)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Descanso', style: TextStyle(color: Colors.white54)),
                  ),
              ],
            ),
            if (!day.isRest) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: day.title,
                decoration: const InputDecoration(
                  labelText: 'Foco do dia (ex.: Peito e tríceps)',
                  isDense: true,
                ),
                onChanged: (v) => day.title = v,
              ),
              const SizedBox(height: 8),
              for (final (i, e) in day.exercises.indexed) _exerciseRow(day, i, e),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('add-exercise-${day.weekDay}'),
                onPressed: () => _addExercise(day),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar exercício'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseRow(DayDraft day, int index, ExerciseDraft e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 52,
            child: TextFormField(
              initialValue: '${e.sets}',
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Séries', isDense: true),
              onChanged: (v) => e.sets = int.tryParse(v) ?? e.sets,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: TextFormField(
              initialValue: e.duration ?? e.reps,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'Reps', isDense: true),
              onChanged: (v) {
                e.reps = v;
                e.duration = null;
              },
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => setState(() => day.exercises.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

/// Escolha de exercício: busca na biblioteca por nome ou grupo muscular, ou digita um nome livre.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  final _query = TextEditingController();
  String? _muscle;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<LibraryExercise> get _results {
    final q = _query.text.trim().toLowerCase();
    return exerciseLibrary
        .where((e) => _muscle == null || e.muscle == _muscle)
        .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('exercise-search'),
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Buscar ou digitar exercício',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _muscle == null,
                      onSelected: (_) => setState(() => _muscle = null),
                    ),
                  ),
                  for (final entry in muscleLabels.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _muscle == entry.key,
                        onSelected: (_) => setState(() => _muscle = entry.key),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: systemBottomInset(context) + 16),
                children: [
                  if (typed.isNotEmpty)
                    ListTile(
                      key: const Key('custom-exercise'),
                      leading: const Icon(Icons.edit_note_rounded),
                      title: Text('Usar "$typed"'),
                      subtitle: const Text('Exercício digitado por você'),
                      onTap: () => Navigator.pop(context, ExerciseDraft(name: typed)),
                    ),
                  for (final e in _results)
                    ListTile(
                      title: Text(e.name),
                      subtitle: Text(
                        '${muscleLabels[e.muscle] ?? e.muscle} · ${e.sets}×${e.reps}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        ExerciseDraft(
                          name: e.name,
                          sets: int.tryParse(e.sets) ?? 3,
                          reps: e.reps,
                          description: e.description,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
