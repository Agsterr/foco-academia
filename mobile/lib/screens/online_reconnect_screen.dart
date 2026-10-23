import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/online_auth_gate.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Aparece quando passou do limite offline (48h): valida a sessão sozinha assim
/// que houver internet. Se a sessão não puder ser renovada, vai direto ao login.
class OnlineReconnectScreen extends StatefulWidget {
  const OnlineReconnectScreen({super.key});

  @override
  State<OnlineReconnectScreen> createState() => _OnlineReconnectScreenState();
}

class _OnlineReconnectScreenState extends State<OnlineReconnectScreen> {
  static const _retryEvery = Duration(seconds: 10);

  bool _loading = false;
  String? _error;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconnect());
    _retryTimer = Timer.periodic(_retryEvery, (_) {
      if (!_loading) _reconnect();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _goToLogin() async {
    _retryTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _reconnect() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await AuthService.instance.ensureOnlineSession();
      if (!ok) {
        if (AuthService.instance.token == null) {
          await _goToLogin();
          return;
        }
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Sem conexão com o servidor. Assim que a internet voltar, o app continua sozinho.';
        });
        return;
      }
      _retryTimer?.cancel();
      try {
        await SyncService.instance.syncAll();
      } catch (_) {}
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on SessionExpiredException {
      await AuthService.instance.logout();
      await _goToLogin();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
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
              const Spacer(),
              Icon(
                _error == null ? Icons.cloud_sync_outlined : Icons.wifi_off,
                size: 64,
                color: Colors.amberAccent,
              ),
              const SizedBox(height: 16),
              Text(
                _error == null ? 'Validando sua sessão...' : 'Aguardando internet',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Faz mais de ${OnlineAuthGate.maxOfflineHours} horas desde a última '
                'validação online. Com a internet ligada, o app valida e continua sozinho.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.amberAccent),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: _loading ? null : _reconnect,
                child: const Text('Tentar agora'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await AuthService.instance.logout();
                        await _goToLogin();
                      },
                child: const Text('Sair e entrar com outra conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
