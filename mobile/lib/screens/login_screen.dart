import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'aluno@academia.com');
  final _password = TextEditingController(text: 'aluno123');
  final _slug = TextEditingController(text: 'academia-demo');
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(
        _email.text.trim(),
        _password.text,
        _slug.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Foco Academia', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('App mobile do aluno'),
              const SizedBox(height: 24),
              TextField(controller: _slug, decoration: const InputDecoration(labelText: 'Código da academia')),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Senha')),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? 'Entrando...' : 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
