import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import 'cardio_screen.dart';
import 'login_screen.dart';
import 'workouts_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendHeartbeat());
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
            child: ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Treino outdoor'),
              subtitle: const Text('GPS em 2º plano, mapa, intervalos e bipes'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CardioScreen()),
              ),
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
        ],
      ),
    );
  }
}
