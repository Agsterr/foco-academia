import 'package:flutter/material.dart';

import '../core/ui/insets.dart';
import '../services/auth_service.dart';
import '../services/workout_service.dart';
import 'login_screen.dart';
import 'program_editor_screen.dart';
import 'templates_screen.dart';

/// Todas as fichas do aluno: as da academia (só leitura) e as próprias (editar, apagar).
/// A ficha ativa é a que aparece em Musculação.
class MyProgramsScreen extends StatefulWidget {
  const MyProgramsScreen({super.key});

  @override
  State<MyProgramsScreen> createState() => _MyProgramsScreenState();
}

class _MyProgramsScreenState extends State<MyProgramsScreen> {
  List<WorkoutProgram> _programs = const [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

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
      final list = await WorkoutService.instance.listPrograms();
      if (!mounted) return;
      setState(() {
        _programs = list;
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

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openEditor([WorkoutProgram? program]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProgramEditorScreen(program: program)),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _confirmDelete(WorkoutProgram program) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar treino?'),
        content: Text('"${program.title}" sai da sua lista. Os treinos que você já fez continuam no histórico.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) await _run(() => WorkoutService.instance.deleteProgram(program.id));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Meus treinos')),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: systemBottomInset(context)),
          child: FloatingActionButton.extended(
            key: const Key('create-program'),
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Montar treino'),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: scrollablePadding(context).copyWith(bottom: 96 + systemBottomInset(context)),
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.auto_awesome_rounded, color: Colors.amberAccent),
                        title: const Text('Treinos prontos'),
                        subtitle: const Text('Musculação, corrida, spinning e bike por nível'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TemplatesScreen()),
                          );
                          _changed = true;
                          await _load();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))
                    else if (_programs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Você ainda não tem treinos. Monte o seu ou escolha um treino pronto.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      for (final p in _programs) _programCard(p),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _programCard(WorkoutProgram p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: p.active
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.greenAccent, width: 1.2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                if (p.active)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text('Ativo', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${p.originLabel} · ${p.trainingDays} ${p.trainingDays == 1 ? 'dia' : 'dias'} de treino',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            Row(
              children: [
                if (!p.active)
                  TextButton(
                    onPressed: () => _run(() => WorkoutService.instance.activateProgram(p.id)),
                    child: const Text('Usar este'),
                  ),
                const Spacer(),
                if (p.ownedByStudent) ...[
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openEditor(p),
                  ),
                  IconButton(
                    tooltip: 'Apagar',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _confirmDelete(p),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
