import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/app_home.dart';
import 'screens/invite_screen.dart';
import 'services/invite_link.dart';
import 'screens/online_reconnect_screen.dart';
import 'services/auth_service.dart';
import 'services/online_auth_gate.dart';
import 'services/subscription_service.dart';
import 'services/sync_service.dart';
import 'presentation/widgets/app_update_listener.dart';

/// Navegação de fora das telas (link de convite aberto com o app já rodando).
final appNavigatorKey = GlobalKey<NavigatorState>();

void _openInvite(String code) {
  appNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => InviteScreen(code: code)));
}

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
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark(),
      // Textos do sistema (calendário, copiar/colar, botões) em português do Brasil.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
    // Compras do Google Play concluídas com o app fechado chegam por aqui.
    SubscriptionService.instance.listen();
    InviteLinks.listen(_openInvite);
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

    if (loggedIn) await AuthService.instance.ensureRole();

    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _needsReconnect = needsReconnect;
      _loading = false;
    });

    // App aberto pelo link do convite: vai direto para o aceite.
    final inviteCode = await InviteLinks.takePendingCode();
    if (inviteCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInvite(inviteCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_loggedIn) return const LoginScreen();
    if (_needsReconnect) return const OnlineReconnectScreen();
    return appHome();
  }
}
