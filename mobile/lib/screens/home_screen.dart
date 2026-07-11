import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/services/app_update_service.dart';
import '../presentation/widgets/app_update_prompt.dart';
import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'cardio_screen.dart';
import 'calorie_stats_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'weight_screen.dart';
import 'workouts_screen.dart';
import '../services/profile_service.dart';

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
  int _caloriesToday = 0;
  double _kmToday = 0;
  double _totalKm = 0;
  int _minutesToday = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendHeartbeat();
      _loadVersion();
      _checkActiveRun();
      _loadTodayStats();
    });
  }

  Future<void> _loadTodayStats() async {
    try {
      final stats = await ProfileService.instance.getCalorieStats();
      if (!mounted) return;
      setState(() {
        _caloriesToday = stats.caloriesToday;
        _kmToday = stats.kmToday;
        _totalKm = stats.totalKm;
        _minutesToday = stats.minutesToday;
      });
    } catch (_) {}
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
          Card(
            color: const Color(0xFF0F172A),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hoje', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('$_caloriesToday', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const Text('kcal', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(_kmToday.toStringAsFixed(1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const Text('km hoje', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('$_minutesToday', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const Text('min', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.route, size: 16, color: Colors.tealAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Total percorrido: ${_totalKm.toStringAsFixed(1)} km',
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Estimativa MET — atualize o peso no perfil para mais precisão',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
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
                  await _loadTodayStats();
                },
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Perfil físico'),
              subtitle: const Text('Peso, altura, idade e objetivo'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                await _loadTodayStats();
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Estatísticas'),
              subtitle: const Text('Calorias, km, rankings e períodos'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalorieStatsScreen()),
              ),
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
              subtitle: const Text('GPS, ritmo, calorias, splits e backup'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardioScreen()),
                );
                await _checkActiveRun();
                await _loadTodayStats();
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
              subtitle: const Text('Ficha semanal, séries e calorias'),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
                );
                await _loadTodayStats();
              },
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
