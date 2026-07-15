import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/services/app_update_service.dart';
import '../presentation/widgets/app_update_prompt.dart';
import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/location_permission_helper.dart';
import '../services/profile_service.dart';
import '../services/sync_service.dart';
import 'calorie_stats_screen.dart';
import 'cardio_history_screen.dart';
import 'cardio_screen.dart';
import 'gps_debug_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
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
  int _caloriesToday = 0;
  double _kmToday = 0;
  double _totalKm = 0;
  int _minutesToday = 0;
  EnergyThreatStatus? _energyThreat;
  bool _energyBannerDismissed = false;
  bool _energyDialogShownThisSession = false;
  bool _energyCheckBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendHeartbeat();
      _loadVersion();
      _checkActiveRun();
      _loadTodayStats();
      _checkEnergyWarning(showDialogIfNeeded: true);
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
      _loadTodayStats();
      // Voltou das configs / outro app: relê Economia e mantém o alerta.
      _checkEnergyWarning(showDialogIfNeeded: false);
    }
  }

  Future<void> _checkEnergyWarning({required bool showDialogIfNeeded}) async {
    if (_energyCheckBusy) return;
    _energyCheckBusy = true;
    try {
      final shouldDialog =
          showDialogIfNeeded && !_energyDialogShownThisSession;
      final flow = await LocationPermissionHelper.promptEnergyOnAppEntry(
        context,
        showDialogIfNeeded: shouldDialog,
      );
      if (!mounted) return;
      if (shouldDialog && flow.status.powerSaverOn) {
        _energyDialogShownThisSession = true;
      }
      setState(() {
        _energyThreat = flow.status;
        // Se ainda está ligada, o alerta volta mesmo se o usuário fechou.
        if (flow.status.powerSaverOn) {
          _energyBannerDismissed = false;
        }
      });
    } finally {
      _energyCheckBusy = false;
    }
  }

  Future<void> _openEnergySettings() async {
    if (_energyThreat?.powerSaverOn == true) {
      await EnergySettingsLauncher.openBatterySaverSettings();
    } else {
      await EnergySettingsLauncher.openIgnoreBatteryOptimizations();
    }
    await _checkEnergyWarning(showDialogIfNeeded: false);
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Foco Academia'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: _sync,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              await _goToLogin();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
          children: [
            _TodaySummaryCard(
              caloriesToday: _caloriesToday,
              kmToday: _kmToday,
              minutesToday: _minutesToday,
              totalKm: _totalKm,
            ),
            if (_energyThreat?.powerSaverOn == true &&
                !_energyBannerDismissed) ...[
              const SizedBox(height: 10),
              _EnergyWarningBanner(
                message: _energyThreat!.shortWarning ??
                    'Economia de energia ligada — desligue para o GPS outdoor',
                onOpenSettings: _openEnergySettings,
                onDismiss: () => setState(() => _energyBannerDismissed = true),
              ),
            ],
            const SizedBox(height: 10),
            if (_hasActiveRun) ...[
              _MenuCard(
                color: const Color(0xFF14532D),
                icon: Icons.restore,
                iconColor: Colors.lightGreenAccent,
                title: 'Corrida interrompida',
                subtitle: 'Toque para retomar o rastreamento GPS',
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
              const SizedBox(height: 8),
            ],
            _MenuCard(
              icon: Icons.person_outline,
              title: 'Perfil físico',
              subtitle: 'Peso, altura, idade e objetivo',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                await _loadTodayStats();
              },
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.bar_chart,
              title: 'Estatísticas',
              subtitle: 'Calorias, km, rankings e períodos',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalorieStatsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.monitor_weight_outlined,
              title: 'Evolução e peso',
              subtitle: 'Gráfico, balança Bluetooth e import do relógio',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeightScreen()),
              ),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.directions_run,
              title: 'Treino outdoor',
              subtitle: 'GPS, ritmo, calorias, splits e backup',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CardioScreen()),
                );
                await _checkActiveRun();
                await _loadTodayStats();
              },
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.history,
              title: 'Histórico e Replay',
              subtitle: 'Calendário Seg–Dom, constância e rotas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CardioHistoryScreen()),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              _MenuCard(
                icon: Icons.bug_report_outlined,
                title: 'Debug GPS',
                subtitle: 'Telemetria para testes de campo (dev)',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GpsDebugScreen()),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.sync,
              title: 'Sincronizar dados',
              subtitle: _status.isEmpty
                  ? 'Toque para enviar dados offline'
                  : _status,
              onTap: _sync,
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: Icons.fitness_center,
              title: 'Musculação',
              subtitle: 'Ficha semanal, séries e calorias',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkoutsScreen()),
                );
                await _loadTodayStats();
              },
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon: _checkingUpdate ? null : Icons.system_update,
              leading: _checkingUpdate
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              title: 'Atualização do app',
              subtitle: 'Versão instalada: $_versionLabel',
              onTap: _checkingUpdate ? null : _checkUpdate,
            ),
            const SizedBox(height: 16),
            Text(
              'v$_versionLabel',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.caloriesToday,
    required this.kmToday,
    required this.minutesToday,
    required this.totalKm,
  });

  final int caloriesToday;
  final double kmToday;
  final int minutesToday;
  final double totalKm;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hoje',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatCell(
                    value: '$caloriesToday',
                    label: 'kcal',
                    labelColor: Colors.orangeAccent,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    value: kmToday.toStringAsFixed(1),
                    label: 'km hoje',
                    labelColor: Colors.lightBlueAccent,
                  ),
                ),
                Expanded(
                  child: _StatCell(
                    value: '$minutesToday',
                    label: 'min',
                    labelColor: Colors.amberAccent,
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
                Flexible(
                  child: Text(
                    'Total percorrido: ${totalKm.toStringAsFixed(1)} km',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Estimativa MET — atualize o peso no perfil para mais precisão',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.labelColor,
  });

  final String value;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: labelColor, fontSize: 12)),
      ],
    );
  }
}

class _EnergyWarningBanner extends StatelessWidget {
  const _EnergyWarningBanner({
    required this.message,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x33F59E0B),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.battery_alert,
              color: Color(0xFFFBBF24),
              size: 22,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Economia de energia ligada',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text(
                'Desligar',
                style: TextStyle(color: Color(0xFFFBBF24)),
              ),
            ),
            IconButton(
              tooltip: 'Fechar',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
              icon: const Icon(Icons.close, color: Color(0xFFFBBF24)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    this.icon,
    this.leading,
    this.iconColor,
    this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData? icon;
  final Widget? leading;
  final Color? iconColor;
  final Color? color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        visualDensity: VisualDensity.compact,
        leading: leading ??
            (icon != null ? Icon(icon, color: iconColor) : null),
        title: Text(title),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
