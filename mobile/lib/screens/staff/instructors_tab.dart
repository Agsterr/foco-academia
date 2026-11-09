import 'package:flutter/material.dart';

import '../../services/staff_service.dart';
import 'person_form.dart';
import 'staff_home_screen.dart';

/// Instrutores da academia com alunos, treinos do mês, nota média e recados pendentes.
class InstructorsTab extends StatefulWidget {
  const InstructorsTab({super.key, required this.service});

  final StaffService service;

  @override
  State<InstructorsTab> createState() => _InstructorsTabState();
}

class _InstructorsTabState extends State<InstructorsTab> {
  final _listKey = GlobalKey<AsyncListViewState<InstructorStats>>();

  Future<void> _create() async {
    final created = await showPersonForm(
      context,
      title: 'Novo instrutor',
      onSubmit: (name, email, password, _) =>
          widget.service.createInstructor(name: name, email: email, password: password),
    );
    if (created == true) _listKey.currentState?.reload();
  }

  Future<void> _toggle(InstructorStats i) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(i.active ? 'Desativar ${i.name}?' : 'Reativar ${i.name}?'),
        content: Text(i.active
            ? 'Ele não consegue mais entrar. Os alunos dele continuam na academia; troque o instrutor deles na aba Alunos.'
            : 'Ele volta a entrar no app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(i.active ? 'Desativar' : 'Reativar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.service.setActive(i.id, !i.active);
      _listKey.currentState?.reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-instructor'),
        onPressed: _create,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Instrutor'),
      ),
      body: AsyncListView<InstructorStats>(
        key: _listKey,
        load: widget.service.instructors,
        empty: 'Nenhum instrutor ainda. Toque em "Instrutor" para cadastrar.',
        itemBuilder: (context, i, _) => Card(
          child: ListTile(
            onTap: () => _toggle(i),
            leading: CircleAvatar(child: Text(i.name.isEmpty ? '?' : i.name.characters.first.toUpperCase())),
            title: Text(i.active ? i.name : '${i.name} (desativado)'),
            subtitle: Text(
              '${i.students} alunos · ${i.sessions30d} treinos em 30 dias'
              '${i.pendingSuggestions > 0 ? '\n${i.pendingSuggestions} recado(s) sem resposta' : ''}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
            isThreeLine: i.pendingSuggestions > 0,
            trailing: i.averageRating == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      Text(i.averageRating!.toStringAsFixed(1).replaceAll('.', ',')),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
