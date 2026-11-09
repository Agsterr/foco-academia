import 'package:flutter/material.dart';

import '../../services/staff_service.dart';
import 'dashboard_tab.dart';
import 'staff_home_screen.dart';

/// Retorno dos alunos: notas dos treinos e recados (sugestões e reclamações) para responder.
class FeedbackTab extends StatefulWidget {
  const FeedbackTab({super.key, required this.service, required this.manager});

  final StaffService service;
  final bool manager;

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Recados'), icon: Icon(Icons.mark_chat_unread_rounded)),
                ButtonSegment(value: 1, label: Text('Notas'), icon: Icon(Icons.star_rounded)),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view,
            children: [
              _SuggestionsList(service: widget.service, manager: widget.manager),
              _RatingsList(service: widget.service, manager: widget.manager),
            ],
          ),
        ),
      ],
    );
  }
}

class _SuggestionsList extends StatefulWidget {
  const _SuggestionsList({required this.service, required this.manager});

  final StaffService service;
  final bool manager;

  @override
  State<_SuggestionsList> createState() => _SuggestionsListState();
}

class _SuggestionsListState extends State<_SuggestionsList> {
  final _listKey = GlobalKey<AsyncListViewState<SuggestionEntry>>();
  bool _onlyPending = true;

  Future<void> _respond(SuggestionEntry s) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ResponseDialog(suggestion: s),
    );
    if (text == null || text.isEmpty) return;
    try {
      await widget.service.respond(s.id, text, manager: widget.manager);
      _listKey.currentState?.reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Resposta enviada.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncListView<SuggestionEntry>(
      key: _listKey,
      load: () => widget.service.suggestions(manager: widget.manager),
      empty: _onlyPending ? 'Nenhum recado esperando resposta.' : 'Nenhum recado ainda.',
      filter: (s) => !_onlyPending || s.pending,
      header: (context, all, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: Text('Sem resposta (${all.where((s) => s.pending).length})'),
              selected: _onlyPending,
              onSelected: (_) => setState(() => _onlyPending = true),
            ),
            ChoiceChip(
              label: Text('Todos (${all.length})'),
              selected: !_onlyPending,
              onSelected: (_) => setState(() => _onlyPending = false),
            ),
          ],
        ),
      ),
      itemBuilder: (context, s, _) {
        final complaint = (s.category ?? '').toLowerCase().startsWith('reclama');
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _respond(s),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        complaint ? Icons.report_problem_rounded : Icons.lightbulb_rounded,
                        size: 18,
                        color: complaint ? Colors.redAccent : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [s.studentName, if (s.category != null && s.category!.isNotEmpty) s.category].join(' · '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (s.createdAt != null)
                        Text(relativeDay(s.createdAt),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(s.message),
                  if (widget.manager && s.instructorName != null) ...[
                    const SizedBox(height: 6),
                    Text('Instrutor: ${s.instructorName}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  if (s.pending)
                    Text('Toque para responder', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600))
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Resposta: ${s.response}'),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// O controller vive no próprio diálogo: descartá-lo fora dele quebrava a animação de saída.
class _ResponseDialog extends StatefulWidget {
  const _ResponseDialog({required this.suggestion});

  final SuggestionEntry suggestion;

  @override
  State<_ResponseDialog> createState() => _ResponseDialogState();
}

class _ResponseDialogState extends State<_ResponseDialog> {
  late final _controller = TextEditingController(text: widget.suggestion.response ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return AlertDialog(
      title: Text('Responder ${s.studentName.split(' ').first}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${s.message}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('response-field'),
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(hintText: 'Sua resposta (o aluno vê no app)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('send-response'),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

class _RatingsList extends StatelessWidget {
  const _RatingsList({required this.service, required this.manager});

  final StaffService service;
  final bool manager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AsyncListView<RatingEntry>(
      load: () => service.ratings(manager: manager),
      empty: 'Os alunos ainda não avaliaram treinos.',
      header: (context, all, _) {
        if (all.isEmpty) return const SizedBox.shrink();
        final counts = <String, int>{};
        for (final r in all) {
          counts[r.rating] = (counts[r.rating] ?? 0) + 1;
        }
        final avg = all.map((r) => r.score).fold<int>(0, (a, b) => a + b) / all.length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(avg.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text('média de ${all.length} avaliações', style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 12),
                RatingDistribution(distribution: counts),
              ],
            ),
          ),
        );
      },
      itemBuilder: (context, r, _) {
        final label = RatingDistribution.levels.where((l) => l.$1 == r.rating).firstOrNull;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (label?.$3 ?? scheme.primary).withValues(alpha: 0.2),
              child: Text('${r.score}', style: TextStyle(color: label?.$3, fontWeight: FontWeight.w800)),
            ),
            title: Text('${r.studentName} · ${label?.$2 ?? r.rating}'),
            subtitle: Text(
              [
                if (r.workout != null && r.workout!.isNotEmpty) r.workout!,
                if (manager && r.instructorName != null) 'Instrutor: ${r.instructorName}',
                if (r.at != null) relativeDay(r.at),
                if (r.comment != null && r.comment!.isNotEmpty) '"${r.comment}"',
              ].join('\n'),
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
        );
      },
    );
  }
}
