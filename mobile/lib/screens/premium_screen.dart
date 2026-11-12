import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/ui/vibrant.dart';
import '../core/ui/insets.dart';
import '../services/subscription_service.dart';

/// Foco Premium: o que inclui, preço da Play Store, assinar e restaurar compra.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key, this.reason});

  /// Mensagem de por que a tela abriu (ex.: recurso bloqueado).
  final String? reason;

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _service = SubscriptionService.instance;
  SubscriptionStatus? _status;
  List<StorePlan> _plans = const [];
  bool _storeAvailable = false;
  bool _loading = true;
  bool _buying = false;
  String? _message;
  StreamSubscription<String>? _events;

  static const _benefits = [
    (Icons.auto_awesome_rounded, 'Treinos prontos', 'Musculação, corrida, spinning e bike por nível'),
    (Icons.edit_note_rounded, 'Monte seus treinos', 'Fichas por dia da semana com 70+ exercícios'),
    (Icons.directions_run_rounded, 'Corrida guiada', 'Fases de corrida e caminhada avisadas no fone'),
    (Icons.insights_rounded, 'Evolução', 'Histórico, calorias e progresso'),
  ];

  @override
  void initState() {
    super.initState();
    _events = _service.events.listen(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    SubscriptionStatus? status;
    var plans = <StorePlan>[];
    var available = false;
    try {
      status = await _service.status();
    } catch (_) {}
    try {
      available = await _service.store.isAvailable();
      if (available) {
        plans = await _service.store.plans(status?.productIds ?? const ['foco_academia_mensal']);
      }
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _status = status;
      _plans = plans;
      _storeAvailable = available;
      _loading = false;
    });
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (event == 'ok') {
      setState(() {
        _buying = false;
        _status = _service.last ?? _status;
        _message = 'Pronto! Foco Premium ativo.';
      });
      return;
    }
    setState(() {
      _buying = event.startsWith('Pagamento em processamento');
      _message = event;
    });
  }

  Future<void> _buy(StorePlan plan) async {
    setState(() {
      _buying = true;
      _message = null;
    });
    try {
      await _service.store.buy(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buying = false;
        _message = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _restore() async {
    setState(() => _message = 'Procurando compras anteriores…');
    try {
      await _service.store.restore();
    } catch (e) {
      if (mounted) setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Foco Premium')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: scrollablePadding(context, all: 20),
              children: [
                HeroCard(
                  gradient: AppTheme.goldGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 44),
                      const SizedBox(height: 10),
                      const Text(
                        'Treine com um plano',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status?.summary ?? 'Treinos prontos e treinos do seu jeito',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                if (widget.reason != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.reason!, style: const TextStyle(color: Colors.amberAccent)),
                ],
                const SizedBox(height: 16),
                for (final (i, (icon, title, subtitle)) in _benefits.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBadge(
                      icon: icon,
                      gradient: const [
                        AppTheme.fireGradient,
                        AppTheme.berryGradient,
                        AppTheme.oceanGradient,
                        AppTheme.freshGradient,
                      ][i % 4],
                      size: 42,
                      glow: false,
                    ),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(subtitle),
                  ),
                const SizedBox(height: 12),
                if (status?.viaAcademy ?? false)
                  const Text(
                    'Você treina por uma academia: tudo isso já está incluído.',
                    textAlign: TextAlign.center,
                  )
                else if (status?.subscribed ?? false)
                  const Text(
                    'Sua assinatura está ativa. Para cancelar, use Assinaturas na Play Store.',
                    textAlign: TextAlign.center,
                  )
                else if (!_storeAvailable || _plans.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.outline),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'A assinatura é feita pela Play Store. Instale o Foco Academia pela Play Store '
                      'para assinar — seus treinos continuam na mesma conta.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final plan in _plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton(
                        key: Key('buy-${plan.id}'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(60),
                          backgroundColor: plan.yearly ? AppTheme.orange : AppTheme.brand,
                        ),
                        onPressed: _buying ? null : () => _buy(plan),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              plan.yearly ? 'Anual · ${plan.price}' : 'Mensal · ${plan.price}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (plan.yearly)
                              const Text('o melhor preço por mês', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                if (_message != null) ...[
                  const SizedBox(height: 8),
                  Text(_message!, textAlign: TextAlign.center),
                ],
                if (_storeAvailable && !(status?.viaAcademy ?? false))
                  TextButton(
                    onPressed: _buying ? null : _restore,
                    child: const Text('Já assinei — restaurar compra'),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Renova automaticamente pelo mesmo valor até você cancelar na Play Store. '
                  'Novas contas têm 7 dias grátis.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
