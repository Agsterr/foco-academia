import 'package:flutter/material.dart';

import '../../services/staff_service.dart';
import 'staff_home_screen.dart';

typedef PersonSubmit = Future<void> Function(String name, String email, String password, String? instructorId);

/// Cadastro de aluno ou instrutor pelo gestor. Devolve true quando salvou.
Future<bool?> showPersonForm(
  BuildContext context, {
  required String title,
  required PersonSubmit onSubmit,
  List<InstructorStats> instructors = const [],
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PersonForm(title: title, onSubmit: onSubmit, instructors: instructors),
  );
}

class _PersonForm extends StatefulWidget {
  const _PersonForm({required this.title, required this.onSubmit, required this.instructors});

  final String title;
  final PersonSubmit onSubmit;
  final List<InstructorStats> instructors;

  @override
  State<_PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<_PersonForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _instructorId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_name.text.trim(), _email.text.trim().toLowerCase(), _password.text, _instructorId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + insets),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Passe o e-mail e a senha para a pessoa entrar no app.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('person-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('person-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                    ? 'Informe um e-mail válido'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('person-password'),
                controller: _password,
                decoration: const InputDecoration(labelText: 'Senha inicial (mínimo 6)'),
                validator: (v) => (v == null || v.length < 6) ? 'Use pelo menos 6 caracteres' : null,
              ),
              if (widget.instructors.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _instructorId,
                  decoration: const InputDecoration(labelText: 'Instrutor responsável'),
                  items: [
                    for (final i in widget.instructors) DropdownMenuItem(value: i.id, child: Text(i.name)),
                  ],
                  onChanged: (v) => setState(() => _instructorId = v),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('person-save'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
