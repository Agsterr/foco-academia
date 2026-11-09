import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

/// Cadastro de aluno avulso (sem academia): monta os próprios treinos e usa os treinos prontos.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _remember = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.register(
        name: _name.text.trim(),
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
        remember: _remember,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      if (mounted) {
        setState(() => _error = msg.contains('SocketException') || msg.contains('ClientException')
            ? 'Sem conexão com a internet. Verifique e tente novamente.'
            : msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Treine do seu jeito',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Monte seus treinos ou escolha um pronto de musculação, corrida, spinning ou bike.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Informe seu nome' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('register-email'),
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
                    key: const Key('register-password'),
                    controller: _password,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Senha (mínimo 6 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                        icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Use pelo menos 6 caracteres' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    key: const Key('register-confirm'),
                    controller: _confirm,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirme a senha',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (v) => v != _password.text ? 'As senhas não conferem' : null,
                  ),
                  const SizedBox(height: 6),
                  CheckboxListTile(
                    value: _remember,
                    onChanged: _loading ? null : (v) => setState(() => _remember = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Lembrar login e senha neste celular'),
                  ),
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
                  FilledButton(
                    key: const Key('register-submit'),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Criar conta'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Se você treina em uma academia que usa o Foco Academia, não precisa criar conta: '
                    'entre com o código e o e-mail que ela cadastrou.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
