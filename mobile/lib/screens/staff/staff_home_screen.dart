import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/staff_service.dart';
import '../login_screen.dart';
import 'dashboard_tab.dart';
import 'feedback_tab.dart';
import 'instructors_tab.dart';
import 'students_tab.dart';

/// Início de instrutores e gestores.
///
/// - Gestor de academia: painel, alunos, instrutores e retorno dos alunos.
/// - Instrutor autônomo: igual à academia, sem a aba de instrutores (ele é o único).
/// - Instrutor de academia: só os próprios alunos e o retorno deles.
class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key, this.service});

  /// Substituível nos testes.
  final StaffService? service;

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> with WidgetsBindingObserver {
  StaffService get _service => widget.service ?? StaffService.instance;

  StaffAccess? _access;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _keepSession();
  }

  Future<void> _keepSession() async {
    try {
      await AuthService.instance.ensureSession();
    } on SessionExpiredException {
      await _goToLogin();
    }
  }

  Future<void> _loadAccess() async {
    setState(() => _error = null);
    try {
      final access = await _service.access();
      if (mounted) setState(() => _access = access);
      _keepSession();
    } on SessionExpiredException {
      await _goToLogin();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _goToLogin() async {
    if (!mounted) return;
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    await _goToLogin();
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    if (access == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Foco Academia'), actions: [_logoutButton()]),
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _loadAccess, child: const Text('Tentar de novo')),
                    ],
                  ),
                ),
        ),
      );
    }

    final isInstructor = AuthService.instance.role == 'INSTRUTOR';
    final tabs = <_StaffTab>[
      if (access.manager)
        _StaffTab('Painel', Icons.insights_rounded, DashboardTab(service: _service)),
      _StaffTab(
        access.manager ? 'Alunos' : 'Meus alunos',
        Icons.groups_rounded,
        StudentsTab(service: _service, manager: access.manager, personal: access.personal, canBuildPrograms: isInstructor),
      ),
      if (access.manager && !access.personal)
        _StaffTab('Instrutores', Icons.badge_rounded, InstructorsTab(service: _service)),
      _StaffTab('Retorno', Icons.forum_rounded, FeedbackTab(service: _service, manager: access.manager)),
    ];
    final index = _tab.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tabs[index].label),
            if (access.academyName != null)
              Text(
                access.personal ? 'Personal · ${access.academyName}' : access.academyName!,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        actions: [_logoutButton()],
      ),
      body: IndexedStack(index: index, children: [for (final t in tabs) t.body]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }

  /// "Sair" com nome (só o ícone passava despercebido): é como se troca de conta neste celular.
  Widget _logoutButton() => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          key: const Key('staff-logout'),
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text('Sair'),
        ),
      );
}

class _StaffTab {
  const _StaffTab(this.label, this.icon, this.body);
  final String label;
  final IconData icon;
  final Widget body;
}

/// Mensagem de erro sem o "Exception:" e com aviso claro de falta de internet.
String friendlyError(Object e) {
  final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Failed host lookup')) {
    return 'Sem conexão com a internet. Verifique e tente novamente.';
  }
  return msg;
}

/// "há 3 dias", "hoje", "nunca".
String relativeDay(DateTime? at, {DateTime? now}) {
  if (at == null) return 'nunca treinou';
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final days = today.difference(DateUtils.dateOnly(at)).inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 30) return 'há $days dias';
  final months = days ~/ 30;
  return months == 1 ? 'há 1 mês' : 'há $months meses';
}

/// Lista com carregamento, erro e "puxar para atualizar".
class AsyncListView<T> extends StatefulWidget {
  const AsyncListView({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.filter,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item, VoidCallback reload) itemBuilder;
  final String empty;
  final Widget Function(BuildContext context, List<T> items, VoidCallback reload)? header;
  final bool Function(T item)? filter;

  @override
  State<AsyncListView<T>> createState() => AsyncListViewState<T>();
}

class AsyncListViewState<T> extends State<AsyncListView<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: _future,
      builder: (context, snap) {
        final bottom = MediaQuery.of(context).viewPadding.bottom;
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 60),
              Text(friendlyError(snap.error!), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Center(child: FilledButton(onPressed: reload, child: const Text('Tentar de novo'))),
            ],
          );
        }
        final all = snap.data ?? const [];
        final items = widget.filter == null ? all : all.where(widget.filter!).toList();
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await _future.catchError((_) => <T>[]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 96 + bottom),
            children: [
              if (widget.header != null) widget.header!(context, all, reload),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    widget.empty,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              for (final item in items) widget.itemBuilder(context, item, reload),
            ],
          ),
        );
      },
    );
  }
}

const _avatarGradients = [
  AppTheme.brandGradient,
  AppTheme.fireGradient,
  AppTheme.oceanGradient,
  AppTheme.freshGradient,
  AppTheme.goldGradient,
  AppTheme.berryGradient,
  AppTheme.nightGradient,
];

/// Inicial da pessoa num círculo colorido (a cor vem do nome, sempre a mesma para cada pessoa).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.dimmed = false, this.size = 44});

  final String name;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradient = _avatarGradients[name.codeUnits.fold<int>(0, (a, b) => a + b) % _avatarGradients.length];
    return Opacity(
      opacity: dimmed ? 0.4 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
        child: Center(
          child: Text(
            name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
          ),
        ),
      ),
    );
  }
}
