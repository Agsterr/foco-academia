import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/online_auth_gate.dart';
import '../services/sync_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Bloqueia o app até reconectar à internet e validar a sessão (máx. 48h offline).
class OnlineReconnectScreen extends StatefulWidget {
  const OnlineReconnectScreen({super.key});

  @override
  State<OnlineReconnectScreen> createState() => _OnlineReconnectScreenState();
}

class _OnlineReconnectScreenState extends State<OnlineReconnectScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _reconnect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await AuthService.instance.ensureOnlineSession();
      if (!ok) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível validar online. Verifique a internet e tente de novo.';
        });
        return;
      }
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
      if (!mounted) return;
      await AuthService.instance.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
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
              const Icon(Icons.wifi_off, size: 64, color: Colors.amberAccent),
              const SizedBox(height: 16),
              const Text(
                'Reconexão necessária',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Faz mais de ${OnlineAuthGate.maxOfflineHours} horas desde a última '
                'validação online. Ative a internet e toque abaixo para continuar usando o app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.75)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _loading ? null : _reconnect,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Conectar e validar'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading
                    ? null
                    : () async {
                        await AuthService.instance.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
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
