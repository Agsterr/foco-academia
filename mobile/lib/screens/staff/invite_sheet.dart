import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/vibrant.dart';
import '../../services/staff_service.dart';
import 'staff_home_screen.dart';

/// Gera um convite por link e já oferece mandar pelo WhatsApp (ou copiar).
Future<void> showCreateInvite(
  BuildContext context, {
  required StaffService service,
  required String role,
  List<InstructorStats> instructors = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CreateInviteSheet(service: service, role: role, instructors: instructors),
  );
}

/// Convites que ainda não foram usados, para reenviar ou cancelar.
Future<void> showOpenInvites(BuildContext context, {required StaffService service}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OpenInvitesSheet(service: service),
  );
}

Future<void> shareInvite(StaffInvite invite) => SharePlus.instance.share(ShareParams(text: invite.shareText));

class _CreateInviteSheet extends StatefulWidget {
  const _CreateInviteSheet({required this.service, required this.role, required this.instructors});

  final StaffService service;
  final String role;
  final List<InstructorStats> instructors;

  @override
  State<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends State<_CreateInviteSheet> {
  final _name = TextEditingController();
  String? _instructorId;
  bool _saving = false;
  String? _error;
  StaffInvite? _invite;

  bool get _forInstructor => widget.role == 'INSTRUTOR';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invite = await widget.service.createInvite(
        role: widget.role,
        name: _name.text,
        instructorId: _instructorId,
      );
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final invite = _invite;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
      child: SingleChildScrollView(
        child: invite == null ? _form(scheme) : InviteResult(invite: invite),
      ),
    );
  }

  Widget _form(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_forInstructor ? 'Convidar instrutor' : 'Convidar aluno',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(
          'Você manda um link; a pessoa toca, cria a senha e a conta já entra '
          '${_forInstructor ? 'na sua equipe' : 'ligada a você'}. O link vale para uma pessoa e um aparelho.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('invite-name-field'),
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome (opcional)', hintText: 'Para personalizar a mensagem'),
        ),
        if (widget.instructors.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _instructorId,
            decoration: const InputDecoration(labelText: 'Instrutor responsável'),
            items: [for (final i in widget.instructors) DropdownMenuItem(value: i.id, child: Text(i.name))],
            onChanged: (v) => setState(() => _instructorId = v),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: scheme.error)),
        ],
        const SizedBox(height: 18),
        GradientButton(
          key: const Key('create-invite'),
          onPressed: _saving ? null : _create,
          loading: _saving,
          icon: Icons.link_rounded,
          label: 'Gerar link de convite',
        ),
      ],
    );
  }
}

/// Código grande, link e botões para mandar.
class InviteResult extends StatelessWidget {
  const InviteResult({super.key, required this.invite});

  final StaffInvite invite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Convite pronto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            children: [
              Text('Código', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              const IconBadge(icon: Icons.mark_email_read_rounded, gradient: AppTheme.brandGradient, size: 52),
              const SizedBox(height: 10),
              SelectableText(
                invite.formattedCode,
                key: const Key('invite-code'),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text(invite.url, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Vale para uma pessoa só, em um aparelho, e vence em 7 dias. '
          'Se o link for repassado e alguém usar antes, ele para de funcionar para os outros.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 16),
        GradientButton(
          key: const Key('share-invite'),
          onPressed: () => shareInvite(invite),
          icon: Icons.send_rounded,
          gradient: AppTheme.freshGradient,
          label: 'Enviar (WhatsApp e outros)',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: invite.shareText));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mensagem copiada.')));
            }
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar mensagem'),
        ),
      ],
    );
  }
}

class _OpenInvitesSheet extends StatefulWidget {
  const _OpenInvitesSheet({required this.service});

  final StaffService service;

  @override
  State<_OpenInvitesSheet> createState() => _OpenInvitesSheetState();
}

class _OpenInvitesSheetState extends State<_OpenInvitesSheet> {
  late Future<List<StaffInvite>> _future = widget.service.openInvites();

  Future<void> _revoke(StaffInvite invite) async {
    try {
      await widget.service.revokeInvite(invite.id);
      setState(() => _future = widget.service.openInvites());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.7,
      child: FutureBuilder<List<StaffInvite>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text(friendlyError(snap.error!)));
          final invites = snap.data!;
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              const Text('Convites pendentes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Ainda não usados. Depois de usados, somem daqui.', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              if (invites.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('Nenhum convite pendente.'))),
              for (final i in invites)
                Card(
                  child: ListTile(
                    title: Text(i.name ?? (i.role == 'INSTRUTOR' ? 'Instrutor' : 'Aluno')),
                    subtitle: Text(
                      '${i.formattedCode} · ${i.role == 'INSTRUTOR' ? 'instrutor' : 'aluno'}'
                      '${i.instructorName != null && i.role != 'INSTRUTOR' ? ' de ${i.instructorName}' : ''}'
                      '${i.expiresAt != null ? '\nvence em ${i.expiresAt!.difference(DateTime.now()).inDays + 1} dia(s)' : ''}',
                    ),
                    isThreeLine: i.expiresAt != null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Reenviar', icon: const Icon(Icons.send_rounded), onPressed: () => shareInvite(i)),
                        IconButton(tooltip: 'Cancelar convite', icon: const Icon(Icons.close_rounded), onPressed: () => _revoke(i)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
