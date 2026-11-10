import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';
import '../services/auth_service.dart';
import '../services/invite_link.dart';
import 'app_home.dart';
import 'invite_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _slug = TextEditingController(text: AuthService.instance.academySlug ?? '');
  bool _loading = false;
  bool _showPassword = false;
  bool _remember = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedLogin();
  }

  /// Preenche com o login lembrado neste aparelho.
  Future<void> _loadSavedLogin() async {
    final saved = await AuthService.instance.savedCredentials();
    if (!mounted || saved == null) return;
    setState(() {
      if (_email.text.isEmpty) _email.text = saved.email;
      if (_password.text.isEmpty) _password.text = saved.password;
      if (_slug.text.isEmpty) _slug.text = saved.slug;
      _remember = true;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _slug.dispose();
    super.dispose();
  }

  String _friendlyError(Object e) {
    if (e is FormatException) return 'Não foi possível falar com o servidor. Tente novamente.';
    final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Failed host lookup')) {
      return 'Sem conexão com a internet. Verifique e tente novamente.';
    }
    return msg.isEmpty ? 'Erro ao entrar. Tente novamente.' : msg;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(
        _email.text.trim(),
        _password.text,
        _slug.text.trim().toLowerCase(),
        remember: _remember,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => appHome()),
      );
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Convite que chegou sem o link abrir o app (ex.: copiou o código da mensagem).
  Future<void> _enterInviteCode() async {
    final code = await showDialog<String>(context: context, builder: (_) => const InviteCodeDialog());
    if (code == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InviteScreen(code: code)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: GlowBackground(
        child: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: IconBadge(icon: Icons.fitness_center_rounded, gradient: AppTheme.brandGradient, size: 72),
                          ),
                          const SizedBox(height: 24),
                          ShaderMask(
                            shaderCallback: (bounds) => AppTheme.brandGradient.createShader(bounds),
                            child: Text(
                              'Foco Academia',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 34,
                                    color: Colors.white,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Treinos, corrida, evolução e sua academia num app só.',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _slug,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Código da academia (opcional)',
                              hintText: 'Deixe em branco se treina por conta própria',
                              prefixIcon: Icon(Icons.storefront_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (v) => (v == null || !v.contains('@')) ? 'Informe um e-mail válido' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _loading ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                                icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Informe a senha' : null,
                          ),
                          const SizedBox(height: 6),
                          CheckboxListTile(
                            value: _remember,
                            onChanged: _loading ? null : (v) => setState(() => _remember = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text('Lembrar login e senha neste celular'),
                            subtitle: Text(
                              'Entra sozinho quando a sessão vencer',
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: scheme.error, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_error!, style: TextStyle(color: scheme.error))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          GradientButton(
                            onPressed: _loading ? null : _submit,
                            loading: _loading,
                            icon: Icons.login_rounded,
                            label: 'Entrar',
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            key: const Key('open-register'),
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    ),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Criar conta grátis'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Recebeu convite do seu instrutor? Toque no link da mensagem '
                            'ou em "Tenho um código de convite".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                          OutlinedButton.icon(
                            key: const Key('have-invite'),
                            onPressed: _loading ? null : _enterInviteCode,
                            icon: const Icon(Icons.mark_email_read_outlined),
                            label: const Text('Tenho um código de convite'),
                          ),
                          TextButton(
                            key: const Key('register-business'),
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(initialProfile: SignupProfile.academia),
                                      ),
                                    ),
                            child: const Text('Sou academia ou personal'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Digitar o código (ou colar o link inteiro) do convite.
class InviteCodeDialog extends StatefulWidget {
  const InviteCodeDialog({super.key});

  @override
  State<InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<InviteCodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    final code = InviteLinks.codeFrom(text) ?? InviteLinks.normalizeCode(text);
    if (code.length < 6) {
      setState(() => _error = 'Digite o código que veio na mensagem (ex.: K7Q2M-X9P3T).');
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código do convite'),
      content: TextField(
        key: const Key('invite-code-field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(hintText: 'K7Q2M-X9P3T ou o link', errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(key: const Key('invite-code-ok'), onPressed: _submit, child: const Text('Continuar')),
      ],
    );
  }
}
