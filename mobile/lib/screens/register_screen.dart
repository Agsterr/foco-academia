import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_home.dart';

/// Perfil escolhido no cadastro.
enum SignupProfile {
  /// Aluno avulso (sem academia): monta os próprios treinos e usa os treinos prontos.
  aluno,

  /// Personal que trabalha sozinho: vê tudo como uma academia de um instrutor só.
  instrutorAutonomo,

  /// Academia com vários instrutores: painel com alunos, instrutores, notas e reclamações.
  academia,
}

/// Cadastro: aluno, instrutor autônomo ou academia.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialProfile = SignupProfile.aluno});

  final SignupProfile initialProfile;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  late SignupProfile _profile = widget.initialProfile;
  final _academyName = TextEditingController();
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
    _academyName.dispose();
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
      if (_profile == SignupProfile.aluno) {
        await AuthService.instance.register(
          name: _name.text.trim(),
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
          remember: _remember,
        );
      } else {
        await AuthService.instance.registerBusiness(
          type: _profile == SignupProfile.academia ? 'ACADEMIA' : 'INSTRUTOR_AUTONOMO',
          academyName: _profile == SignupProfile.academia ? _academyName.text.trim() : null,
          name: _name.text.trim(),
          email: _email.text.trim().toLowerCase(),
          password: _password.text,
          remember: _remember,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => appHome()),
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

  String get _headline => switch (_profile) {
        SignupProfile.aluno => 'Treine do seu jeito',
        SignupProfile.instrutorAutonomo => 'Seus alunos na palma da mão',
        SignupProfile.academia => 'Sua academia no controle',
      };

  String get _pitch => switch (_profile) {
        SignupProfile.aluno =>
          'Monte seus treinos ou escolha um pronto de musculação, corrida, spinning ou bike.',
        SignupProfile.instrutorAutonomo =>
          'Cadastre seus alunos, monte as fichas e acompanhe treinos, notas e recados de cada um.',
        SignupProfile.academia =>
          'Cadastre instrutores e alunos e acompanhe desempenho, notas, reclamações e gráficos da academia.',
      };

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
                  Text('Você é', style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  SegmentedButton<SignupProfile>(
                    key: const Key('register-profile'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: SignupProfile.aluno,
                        label: Text('Aluno'),
                        icon: Icon(Icons.directions_run_rounded),
                      ),
                      ButtonSegment(
                        value: SignupProfile.instrutorAutonomo,
                        label: Text('Personal'),
                        icon: Icon(Icons.sports_rounded),
                      ),
                      ButtonSegment(
                        value: SignupProfile.academia,
                        label: Text('Academia'),
                        icon: Icon(Icons.store_rounded),
                      ),
                    ],
                    selected: {_profile},
                    onSelectionChanged: _loading ? null : (v) => setState(() => _profile = v.first),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _headline,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(_pitch, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  if (_profile == SignupProfile.academia) ...[
                    TextFormField(
                      key: const Key('register-academy'),
                      controller: _academyName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome da academia',
                        prefixIcon: Icon(Icons.store_mall_directory_outlined),
                      ),
                      validator: (v) =>
                          (_profile == SignupProfile.academia && (v == null || v.trim().length < 2))
                              ? 'Informe o nome da academia'
                              : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    key: const Key('register-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: InputDecoration(
                      labelText: _profile == SignupProfile.academia ? 'Seu nome (responsável)' : 'Nome',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
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
                  if (_profile == SignupProfile.aluno)
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
