import 'package:flutter/material.dart';

import '../core/ui/vibrant.dart';
import '../services/auth_service.dart';
import 'app_home.dart';
import 'staff/staff_home_screen.dart' show friendlyError;

/// Aceite do convite que o instrutor ou a academia mandou: a conta já sai ligada a eles.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, required this.code});

  final String code;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late Future<Map<String, dynamic>> _preview;
  bool _hasAccount = false;
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preview = AuthService.instance.previewInvite(widget.code).then((data) {
      final name = data['name'] as String?;
      if (name != null && _name.text.isEmpty) _name.text = name;
      return data;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.acceptInvite(
        code: widget.code,
        name: _hasAccount ? null : _name.text,
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => appHome()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Convite')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _preview,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_off_rounded, size: 48, color: scheme.error),
                      const SizedBox(height: 12),
                      Text(friendlyError(snap.error!), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            final invite = snap.data!;
            final instructor = invite['role'] == 'INSTRUTOR';
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InviteHeader(invite: invite),
                      const SizedBox(height: 20),
                      if (!instructor)
                        SwitchListTile(
                          key: const Key('invite-has-account'),
                          value: _hasAccount,
                          onChanged: _loading ? null : (v) => setState(() => _hasAccount = v),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Já tenho conta no app'),
                          subtitle: const Text('Seus treinos e histórico continuam; só passa a ser da academia.'),
                        ),
                      if (!_hasAccount) ...[
                        TextFormField(
                          key: const Key('invite-name'),
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Seu nome',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        key: const Key('invite-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                            ? 'Informe um e-mail válido'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('invite-password'),
                        controller: _password,
                        obscureText: !_showPassword,
                        textInputAction: _hasAccount ? TextInputAction.done : TextInputAction.next,
                        autofillHints: [_hasAccount ? AutofillHints.password : AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: _hasAccount ? 'Senha da sua conta' : 'Crie uma senha (mínimo 6)',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? 'Use pelo menos 6 caracteres' : null,
                      ),
                      if (!_hasAccount) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('invite-confirm'),
                          controller: _confirm,
                          obscureText: !_showPassword,
                          decoration: const InputDecoration(
                            labelText: 'Confirme a senha',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
                          ),
                          child: Text(_error!, style: TextStyle(color: scheme.error)),
                        ),
                      ],
                      const SizedBox(height: 18),
                      GradientButton(
                        key: const Key('invite-accept'),
                        onPressed: _loading ? null : _accept,
                        loading: _loading,
                        icon: _hasAccount ? Icons.link_rounded : Icons.celebration_rounded,
                        label: _hasAccount ? 'Vincular minha conta' : 'Aceitar convite',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.phone_android_rounded, size: 18, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sua conta fica neste celular. Se trocar de aparelho, peça para '
                              '${instructor ? 'a academia' : 'seu instrutor'} liberar.',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InviteHeader extends StatelessWidget {
  const _InviteHeader({required this.invite});

  final Map<String, dynamic> invite;

  @override
  Widget build(BuildContext context) {
    final instructor = invite['role'] == 'INSTRUTOR';
    final personal = invite['personal'] == true;
    final academy = invite['academyName'] as String? ?? '';
    final teacher = invite['instructorName'] as String?;
    final invitedBy = invite['invitedBy'] as String? ?? academy;
    final title = instructor
        ? 'Você foi convidado(a) para a equipe da $academy'
        : teacher != null
            ? 'Treine com $teacher${personal ? '' : ' na $academy'}'
            : 'Treine na $academy';
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
            child: Icon(instructor ? Icons.badge_rounded : Icons.fitness_center_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            instructor
                ? 'Crie sua conta de instrutor para montar fichas e acompanhar seus alunos.'
                : '$invitedBy já deixou tudo pronto: crie sua conta e suas fichas aparecem aqui.',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
