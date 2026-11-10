import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../data/services/app_update_service.dart';
import '../presentation/widgets/app_update_prompt.dart';
import '../services/active_run_store.dart';
import '../services/auth_service.dart';
import '../services/online_auth_gate.dart';
import '../services/profile_service.dart';
import '../services/sync_service.dart';
import 'calorie_stats_screen.dart';
import 'cardio_history_screen.dart';
import 'cardio_screen.dart';
import 'gps_debug_screen.dart';
import 'login_screen.dart';
import 'online_reconnect_screen.dart';
import 'profile_screen.dart';
import 'weight_screen.dart';
import 'workouts_screen.dart';
import 'premium_screen.dart';
import 'templates_screen.dart';
import '../services/subscription_service.dart';
import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';

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
      _loadSubscription();
    });
  }

  SubscriptionStatus? _subscription;

  Future<void> _loadSubscription() async {
    try {
      final status = await SubscriptionService.instance.status();
      if (mounted) setState(() => _subscription = status);
    } catch (_) {
      // Sem rede: o cartão some até a próxima abertura.
    }
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
      if (await OnlineAuthGate.instance.requiresOnlineReconnect()) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnlineReconnectScreen()),
        );
        return;
      }
      await AuthService.instance.ensureSession();
      try {
        await SyncService.instance.syncAll();
      } catch (_) {}
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

  /// Escondido nas capturas da Play Store (`--dart-define=PLAY_SCREENSHOTS=true`).
  static const _screenshotMode = bool.fromEnvironment('PLAY_SCREENSHOTS');

  Future<void> _open(Widget screen, {bool reloadStats = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (reloadStats) {
      await _checkActiveRun();
      await _loadTodayStats();
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Bom dia' : (hour < 18 ? 'Boa tarde' : 'Boa noite');
    final name = AuthService.instance.userName?.trim().split(' ').first;
    return name == null || name.isEmpty ? part : '$part, $name';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const Row(
          children: [
            IconBadge(icon: Icons.fitness_center_rounded, gradient: AppTheme.brandGradient, size: 34, glow: false),
            SizedBox(width: 10),
            Text('Foco Academia'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: _sync,
            icon: const Icon(Icons.sync_rounded),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await AuthService.instance.logout();
              if (!context.mounted) return;
              await _goToLogin();
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + bottomInset),
          children: [
            Text(_greeting, style: Theme.of(context).textTheme.headlineSmall),
            const Text('Bora treinar? Escolha o que vai fazer hoje.', style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            _TodaySummaryCard(
              caloriesToday: _caloriesToday,
              kmToday: _kmToday,
              minutesToday: _minutesToday,
              totalKm: _totalKm,
            ),
            if (_hasActiveRun) ...[
              const SizedBox(height: 12),
              VibrantTile(
                icon: Icons.restore_rounded,
                gradient: AppTheme.freshGradient,
                title: 'Corrida interrompida',
                subtitle: 'Toque para retomar o rastreamento GPS',
                onTap: () => _open(const CardioScreen(autoResume: true), reloadStats: true),
              ),
            ],
            const SectionHeader('Treinar'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                FeatureTile(
                  icon: Icons.fitness_center_rounded,
                  gradient: AppTheme.fireGradient,
                  title: 'Musculação',
                  subtitle: 'Ficha da semana, séries e calorias',
                  onTap: () => _open(const WorkoutsScreen(), reloadStats: true),
                ),
                FeatureTile(
                  icon: Icons.directions_run_rounded,
                  gradient: AppTheme.freshGradient,
                  title: 'Treino outdoor',
                  subtitle: 'GPS, ritmo, splits e voz',
                  onTap: () => _open(const CardioScreen(), reloadStats: true),
                ),
                FeatureTile(
                  icon: Icons.auto_awesome_rounded,
                  gradient: AppTheme.berryGradient,
                  title: 'Treinos prontos',
                  subtitle: 'Musculação, corrida, spinning e bike',
                  onTap: () => _open(const TemplatesScreen(), reloadStats: true),
                ),
                FeatureTile(
                  icon: Icons.map_rounded,
                  gradient: AppTheme.oceanGradient,
                  title: 'Histórico',
                  subtitle: 'Calendário, rotas e replay',
                  onTap: () => _open(const CardioHistoryScreen()),
                ),
                FeatureTile(
                  icon: Icons.insights_rounded,
                  gradient: AppTheme.goldGradient,
                  title: 'Estatísticas',
                  subtitle: 'Calorias, km e rankings',
                  onTap: () => _open(const CalorieStatsScreen()),
                ),
                FeatureTile(
                  icon: Icons.monitor_weight_rounded,
                  gradient: AppTheme.nightGradient,
                  title: 'Evolução',
                  subtitle: 'Peso, gráfico e balança',
                  onTap: () => _open(const WeightScreen()),
                ),
              ],
            ),
            if (_subscription != null && !_subscription!.viaAcademy) ...[
              const SizedBox(height: 16),
              HeroCard(
                key: const Key('premium-card'),
                gradient: AppTheme.goldGradient,
                padding: const EdgeInsets.all(18),
                onTap: () async {
                  await _open(const PremiumScreen());
                  await _loadSubscription();
                },
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Foco Premium',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(_subscription!.summary, style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ],
            const SectionHeader('Sua conta', gradient: AppTheme.oceanGradient),
            VibrantTile(
              icon: Icons.person_rounded,
              gradient: AppTheme.berryGradient,
              title: 'Perfil físico',
              subtitle: 'Peso, altura, idade e objetivo',
              onTap: () => _open(const ProfileScreen(), reloadStats: true),
            ),
            VibrantTile(
              icon: Icons.cloud_sync_rounded,
              gradient: AppTheme.oceanGradient,
              title: 'Sincronizar dados',
              subtitle: _status.isEmpty ? 'Envia o que ficou salvo sem internet' : _status,
              onTap: _sync,
            ),
            VibrantTile(
              icon: Icons.system_update_rounded,
              gradient: AppTheme.freshGradient,
              leading: _checkingUpdate
                  ? const SizedBox(
                      width: 46,
                      height: 46,
                      child: Padding(padding: EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.4)),
                    )
                  : null,
              title: 'Atualização do app',
              subtitle: 'Versão instalada: $_versionLabel',
              onTap: _checkingUpdate ? null : _checkUpdate,
            ),
            if (kDebugMode && !_screenshotMode)
              VibrantTile(
                icon: Icons.bug_report_rounded,
                gradient: AppTheme.fireGradient,
                title: 'Debug GPS',
                subtitle: 'Telemetria para testes de campo (dev)',
                onTap: () => _open(const GpsDebugScreen()),
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
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Hoje', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatCell(icon: Icons.local_fire_department_rounded, value: '$caloriesToday', label: 'kcal')),
              Expanded(child: _StatCell(icon: Icons.route_rounded, value: _decimal(kmToday), label: 'km')),
              Expanded(child: _StatCell(icon: Icons.timer_rounded, value: '$minutesToday', label: 'min')),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Total percorrido: ${_decimal(totalKm)} km',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 5.2 → "5,2" (formato brasileiro).
String _decimal(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

class _StatCell extends StatelessWidget {
  const _StatCell({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1),
        ),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
      ],
    );
  }
}
