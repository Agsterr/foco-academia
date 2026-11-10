import 'package:flutter/material.dart';

import '../../services/staff_service.dart';
import '../program_editor_screen.dart';
import 'invite_sheet.dart';
import 'person_form.dart';
import 'staff_home_screen.dart';

/// Alunos com atividade e média das notas. O gestor vê todos da academia; o instrutor, só os dele.
class StudentsTab extends StatefulWidget {
  const StudentsTab({
    super.key,
    required this.service,
    required this.manager,
    required this.personal,
    required this.canBuildPrograms,
  });

  final StaffService service;
  final bool manager;
  final bool personal;

  /// Só instrutores montam fichas (o gestor distribui os alunos entre eles).
  final bool canBuildPrograms;

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _listKey = GlobalKey<AsyncListViewState<StaffStudent>>();
  String _query = '';
  bool _onlyIdle = false;

  void _reload() => _listKey.currentState?.reload();

  Future<List<InstructorStats>> _activeInstructors() async {
    if (!widget.manager || widget.personal) return const [];
    try {
      return (await widget.service.instructors()).where((i) => i.active).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Convite por link é o caminho principal; o gestor também pode cadastrar com senha.
  Future<void> _add() async {
    if (!widget.manager) return _invite();
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('add-by-invite'),
              leading: const Icon(Icons.link_rounded),
              title: const Text('Convidar por link (recomendado)'),
              subtitle: const Text('O aluno toca no link e a conta já vem pronta'),
              onTap: () => Navigator.pop(context, 'invite'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded),
              title: const Text('Cadastrar com e-mail e senha'),
              subtitle: const Text('Você cria a conta e passa a senha'),
              onTap: () => Navigator.pop(context, 'create'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'invite') await _invite();
    if (choice == 'create') await _create();
  }

  Future<void> _invite() async {
    final instructors = await _activeInstructors();
    if (!mounted) return;
    await showCreateInvite(context, service: widget.service, role: 'ALUNO', instructors: instructors);
  }

  Future<void> _create() async {
    final instructors = await _activeInstructors();
    if (!mounted) return;
    final created = await showPersonForm(
      context,
      title: 'Novo aluno',
      instructors: instructors,
      onSubmit: (name, email, password, instructorId) => widget.service.createStudent(
        name: name,
        email: email,
        password: password,
        instructorId: instructorId,
      ),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('new-student'),
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(widget.manager ? 'Aluno' : 'Convidar aluno'),
      ),
      body: AsyncListView<StaffStudent>(
        key: _listKey,
        load: () => widget.service.students(manager: widget.manager),
        empty: widget.manager
            ? 'Nenhum aluno ainda. Toque em "Aluno" para convidar.'
            : 'Nenhum aluno ligado a você ainda. Toque em "Convidar aluno" e mande o link.',
        filter: (s) =>
            (_query.isEmpty || s.name.toLowerCase().contains(_query) || s.email.toLowerCase().contains(_query)) &&
            (!_onlyIdle || s.inactiveFor(now)),
        header: (context, all, _) {
          final idle = all.where((s) => s.active && s.inactiveFor(now)).length;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar aluno',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActionChip(
                      key: const Key('open-invites'),
                      avatar: const Icon(Icons.mark_email_unread_outlined, size: 18),
                      label: const Text('Convites pendentes'),
                      onPressed: () => showOpenInvites(context, service: widget.service),
                    ),
                    ChoiceChip(
                      label: Text('Todos (${all.length})'),
                      selected: !_onlyIdle,
                      onSelected: (_) => setState(() => _onlyIdle = false),
                    ),
                    ChoiceChip(
                      label: Text('Sem treinar há 14 dias ($idle)'),
                      selected: _onlyIdle,
                      onSelected: (_) => setState(() => _onlyIdle = true),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        itemBuilder: (context, s, reload) => _StudentCard(
          student: s,
          now: now,
          showInstructor: widget.manager && !widget.personal,
          onTap: () => _openActions(s),
        ),
      ),
    );
  }

  Future<void> _openActions(StaffStudent s) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.email),
            ),
            const Divider(height: 1),
            if (widget.canBuildPrograms && s.active)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Montar ficha de treino'),
                subtitle: const Text('Substitui a ficha ativa do aluno'),
                onTap: () => Navigator.pop(context, 'program'),
              ),
            if (widget.manager && !widget.personal)
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text('Trocar instrutor'),
                onTap: () => Navigator.pop(context, 'instructor'),
              ),
            ListTile(
              key: const Key('release-device'),
              leading: const Icon(Icons.phonelink_erase_rounded),
              title: const Text('Liberar aparelho'),
              subtitle: const Text('Trocou de celular: libera para entrar no novo'),
              onTap: () => Navigator.pop(context, 'release'),
            ),
            if (widget.manager)
              ListTile(
                leading: Icon(s.active ? Icons.block_rounded : Icons.check_circle_outline_rounded),
                title: Text(s.active ? 'Desativar aluno' : 'Reativar aluno'),
                subtitle: Text(s.active ? 'Ele não consegue mais entrar no app' : 'Ele volta a entrar no app'),
                onTap: () => Navigator.pop(context, 'active'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'program':
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => ProgramEditorScreen(studentId: s.id, studentName: s.name)),
        );
        if (saved == true) _snack('Ficha enviada para ${s.name}.');
      case 'instructor':
        await _changeInstructor(s);
      case 'release':
        await _run(() => widget.service.releaseDevices(s.id), 'Aparelho liberado. ${s.name} já pode entrar no celular novo.');
      case 'active':
        await _run(() => widget.service.setActive(s.id, !s.active), s.active ? 'Aluno desativado.' : 'Aluno reativado.');
    }
  }

  Future<void> _changeInstructor(StaffStudent s) async {
    List<InstructorStats> instructors;
    try {
      instructors = (await widget.service.instructors()).where((i) => i.active).toList();
    } catch (e) {
      _snack(friendlyError(e));
      return;
    }
    if (!mounted) return;
    if (instructors.isEmpty) {
      _snack('Cadastre um instrutor primeiro.');
      return;
    }
    final picked = await showModalBottomSheet<InstructorStats>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Escolha o instrutor', style: TextStyle(fontWeight: FontWeight.w700))),
            for (final i in instructors)
              ListTile(
                leading: Icon(i.id == s.instructorId ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(i.name),
                subtitle: Text('${i.students} alunos'),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked.id == s.instructorId) return;
    await _run(() => widget.service.assignInstructor(s.id, picked.id), '${s.name} agora é aluno de ${picked.name}.');
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      _snack(done);
      _reload();
    } catch (e) {
      _snack(friendlyError(e));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.now, required this.showInstructor, required this.onTap});

  final StaffStudent student;
  final DateTime now;
  final bool showInstructor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = student;
    final scheme = Theme.of(context).colorScheme;
    final idle = s.active && s.inactiveFor(now);
    final details = [
      relativeDay(s.lastActivityAt, now: now),
      '${s.sessions30d} treino${s.sessions30d == 1 ? '' : 's'} em 30 dias',
      if (showInstructor) s.instructorName ?? 'sem instrutor',
    ].join(' · ');
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: PersonAvatar(name: s.name, dimmed: !s.active),
        title: Text(
          s.active ? s.name : '${s.name} (desativado)',
          style: TextStyle(color: s.active ? null : scheme.onSurfaceVariant),
        ),
        subtitle: Text(details, style: TextStyle(color: idle ? Colors.amber : scheme.onSurfaceVariant, fontSize: 12)),
        trailing: s.averageRating == null
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                  Text(s.averageRating!.toStringAsFixed(1).replaceAll('.', ',')),
                ],
              ),
      ),
    );
  }
}
