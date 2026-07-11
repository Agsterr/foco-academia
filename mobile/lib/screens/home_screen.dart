import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/services/app_update_service.dart';
import '../presentation/widgets/app_update_prompt.dart';
import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'cardio_screen.dart';
import 'login_screen.dart';
import 'weight_screen.dart';
import 'workouts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _updateService = AppUpdateService();
  String _status = '';
  String _versionLabel = '...';
  bool _checkingUpdate = false;
  bool _hasActiveRun = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendHeartbeat();
      _loadVersion();
      _checkActiveRun();
    });
  }

  Future<void> _checkActiveRun() async {
    final flag = await ActiveRunStore.instance.hasActiveFlag();
    final snap = flag ? await ActiveRunStore.instance.load() : null;
    if (!mounted) return;
    setState(() => _hasActiveRun = snap != null);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sendHeartbeat();
      _loadVersion();
      _checkActiveRun();
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _versionLabel = '${info.version}+${info.buildNumber}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLabel = 'desconhecida');
    }
  }

  Future<void> _sendHeartbeat() async {
    try {
      await AuthService.instance.heartbeat();
    } on SessionExpiredException {
      if (!mounted) return;
      await _goToLogin();
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _sync() async {
    setState(() => _status = 'Sincronizando...');
    try {
      final n = await SyncService.instance.syncAll();
      setState(() => _status = '$n item(ns) sincronizado(s)');
    } on SessionExpiredException {
      setState(() => _status = 'Sessão expirada');
      await _goToLogin();
    } catch (e) {
      setState(() => _status = 'Offline ou erro: $e');
    }
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final message = await AppUpdatePrompt.checkAndPrompt(
        context,
        service: _updateService,
        manual: true,
      );
      if (!mounted) return;
      await _loadVersion();
      if (!mounted) return;
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao verificar atualização: $e')),
      );
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foco Academia'),
        actions: [
          IconButton(onPressed: _sync, icon: const Icon(Icons.sync)),
          IconButton(
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              await _goToLogin();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasActiveRun)
            Card(
              color: const Color(0xFF14532D),
              child: ListTile(
                leading: const Icon(Icons.restore, color: Colors.lightGreenAccent),
                title: const Text('Corrida interrompida'),
                subtitle: const Text('Toque para retomar o rastreamento GPS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CardioScreen(autoResume: true),
                    ),
                  );
                  await _checkActiveRun();
                },
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Evolução e peso'),
              subtitle: const Text('Gráfico, balança Bluetooth e import do relógio'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeightScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Treino outdoor'),
              subtitle: const Text('GPS, ritmo, splits, GPX/TCX e backup'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardioScreen()),
                );
                await _checkActiveRun();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sincronizar dados'),
              subtitle: Text(_status.isEmpty ? 'Toque para enviar dados offline' : _status),
              onTap: _sync,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Musculação'),
              subtitle: const Text('Ficha semanal, séries e mídia'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: _checkingUpdate
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.system_update),
              title: const Text('Atualização do app'),
              subtitle: Text('Versão instalada: $_versionLabel'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _checkingUpdate ? null : _checkUpdate,
            ),
          ),
        ],
      ),
    );
  }
}
