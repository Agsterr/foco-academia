import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/online_reconnect_screen.dart';
import 'services/auth_service.dart';
import 'services/online_auth_gate.dart';
import 'services/sync_service.dart';
import 'presentation/widgets/app_update_listener.dart';

void main() {
  runApp(const FocoAcademiaApp());
}

class FocoAcademiaApp extends StatelessWidget {
  const FocoAcademiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foco Academia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppUpdateListener(child: _Bootstrap()),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _loading = true;
  bool _loggedIn = false;
  bool _needsReconnect = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasToken = await AuthService.instance.load();
    var loggedIn = hasToken;
    var needsReconnect = false;

    if (hasToken) {
      final withinWindow = await OnlineAuthGate.instance.isWithinOfflineWindow();
      if (!withinWindow) {
        final online = await AuthService.instance.ensureOnlineSession();
        if (online) {
          loggedIn = true;
          try {
            await SyncService.instance.syncAll();
          } catch (_) {}
        } else if (AuthService.instance.token == null) {
          // Sessão vencida e sem login lembrado que funcione: direto para o login.
          loggedIn = false;
        } else {
          // Só falta internet: a tela de reconexão tenta de novo sozinha.
          loggedIn = true;
          needsReconnect = true;
        }
      } else {
        await AuthService.instance.refreshSession();
        loggedIn = AuthService.instance.token != null;
        if (loggedIn) {
          try {
            await SyncService.instance.syncAll();
          } catch (_) {}
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _needsReconnect = needsReconnect;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) return const LoginScreen();
    if (_needsReconnect) return const OnlineReconnectScreen();
    return const HomeScreen();
  }
}
