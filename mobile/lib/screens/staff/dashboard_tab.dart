import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/staff_service.dart';
import '../../core/ui/vibrant.dart';
import 'staff_home_screen.dart';

/// Painel da academia: números do mês, gráfico de 6 meses, notas e ranking dos instrutores.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.service});

  final StaffService service;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late Future<ManagerDashboard> _future;
  bool _showStudents = false;

  @override
  void initState() {
    super.initState();
    _future = widget.service.dashboard();
  }

  Future<void> _reload() async {
    setState(() => _future = widget.service.dashboard());
    await _future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ManagerDashboard>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(friendlyError(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _reload, child: const Text('Tentar de novo')),
                ],
              ),
            ),
          );
        }
        final d = snap.data!;
        final bottom = MediaQuery.of(context).viewPadding.bottom;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, 32 + bottom),
            children: [
              _KpiGrid(dashboard: d),
              const SizedBox(height: 12),
              _Indicators(dashboard: d),
              const SizedBox(height: 12),
              _Section(
                title: 'Últimos 6 meses',
                trailing: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: false, label: Text('Treinos')),
                    ButtonSegment(value: true, label: Text('Alunos')),
                  ],
                  selected: {_showStudents},
                  onSelectionChanged: (v) => setState(() => _showStudents = v.first),
                ),
                child: BarChart(
                  key: const Key('months-chart'),
                  bars: [
                    for (final m in d.months)
                      (label: m.shortLabel, value: _showStudents ? m.activeStudents : m.sessions),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Notas dos treinos (30 dias)',
                child: RatingDistribution(distribution: d.ratingDistribution),
              ),
              if (!d.personal) ...[
                const SizedBox(height: 12),
                _Section(
                  title: 'Instrutores (30 dias)',
                  child: d.instructorRanking.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Cadastre instrutores na aba Instrutores.'),
                        )
                      : Column(
                          children: [
                            for (final (i, s) in d.instructorRanking.indexed) _RankingRow(position: i + 1, stats: s),
                          ],
                        ),
                ),
              ],
              const SizedBox(height: 12),
              _PlanCard(dashboard: d),
            ],
          ),
        );
      },
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});

  final ManagerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final tiles = [
      _Kpi('Alunos', '${d.students}', Icons.groups_rounded,
          d.personal ? null : '${d.instructors} instrutor${d.instructors == 1 ? '' : 'es'}',
          gradient: AppTheme.brandGradient),
      _Kpi('Treinaram na semana', '${d.activeStudents7d}', Icons.local_fire_department_rounded, null,
          gradient: AppTheme.fireGradient),
      _Kpi('Treinos em 30 dias', '${d.sessions30d}', Icons.fitness_center_rounded, null,
          gradient: AppTheme.oceanGradient),
      _Kpi(
        'Nota média',
        d.averageRating30d == null ? '—' : d.averageRating30d!.toStringAsFixed(1).replaceAll('.', ','),
        Icons.star_rounded,
        'de 1 a 5',
        gradient: AppTheme.goldGradient,
      ),
      _Kpi('Recados pendentes', '${d.pendingSuggestions}', Icons.mark_chat_unread_rounded,
          d.pendingSuggestions > 0 ? 'responda na aba Retorno' : null,
          gradient: d.pendingSuggestions > 0 ? AppTheme.berryGradient : AppTheme.freshGradient),
      _Kpi('Engajamento', '${d.students == 0 ? 0 : (d.activeStudents7d * 100 / d.students).round()}%',
          Icons.trending_up_rounded, 'treinaram em 7 dias',
          gradient: AppTheme.freshGradient),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [for (final t in tiles) SizedBox(width: width, child: t)],
        );
      },
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon, this.hint, {required this.gradient});

  final String label;
  final String value;
  final IconData icon;
  final String? hint;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glow = AppTheme.glowOf(gradient);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [glow.withValues(alpha: 0.24), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: glow.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, gradient: gradient, size: 38),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          if (hint != null)
            Text(hint!, style: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }
}

/// Cálculos a partir dos números do painel.
class _Indicators extends StatelessWidget {
  const _Indicators({required this.dashboard});

  final ManagerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final engagement = d.students == 0 ? 0.0 : d.activeStudents7d / d.students;
    final lastMonth = d.months.isEmpty ? null : d.months.last;
    final perActive = (lastMonth == null || lastMonth.activeStudents == 0)
        ? null
        : lastMonth.sessions / lastMonth.activeStudents;
    final previous = d.months.length < 2 ? null : d.months[d.months.length - 2];
    final growth = (previous == null || previous.sessions == 0 || lastMonth == null)
        ? null
        : (lastMonth.sessions - previous.sessions) / previous.sessions;

    return _Section(
      title: 'Indicadores',
      child: Column(
        children: [
          _ProgressRow(
            label: 'Engajamento semanal',
            detail: '${(engagement * 100).round()}% dos alunos treinaram nos últimos 7 dias',
            value: engagement,
          ),
          const Divider(height: 20),
          _StatLine(
            label: 'Treinos por aluno ativo (mês)',
            value: perActive == null ? '—' : perActive.toStringAsFixed(1).replaceAll('.', ','),
          ),
          _StatLine(
            label: 'Treinos vs. mês anterior',
            value: growth == null ? '—' : '${growth >= 0 ? '+' : ''}${(growth * 100).round()}%',
            color: growth == null ? null : (growth >= 0 ? Colors.greenAccent : Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.detail, required this.value});

  final String label;
  final String detail;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 10),
        ),
        const SizedBox(height: 6),
        Text(detail, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Gráfico de barras simples (sem dependência externa), com o valor em cima de cada barra.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.bars, this.height = 190});

  final List<({String label, int value})> bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = bars.fold<int>(0, (m, b) => b.value > m ? b.value : m);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, b) in bars.indexed)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  children: [
                    Text('${b.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    // A barra ocupa o que sobra entre os rótulos (funciona com fonte grande).
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: max == 0 ? 0.02 : 0.02 + 0.98 * b.value / max,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: i == bars.length - 1 ? AppTheme.brandGradient : null,
                              color: i == bars.length - 1 ? null : scheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(b.label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barras horizontais com a contagem de cada nota.
class RatingDistribution extends StatelessWidget {
  const RatingDistribution({super.key, required this.distribution});

  final Map<String, int> distribution;

  static const levels = [
    ('MUITO_BOM', 'Muito bom', Color(0xFF22C55E)),
    ('BOM', 'Bom', Color(0xFF84CC16)),
    ('FACIL', 'Fácil', Color(0xFF38BDF8)),
    ('RUIM', 'Ruim', Color(0xFFF59E0B)),
    ('MUITO_RUIM', 'Muito ruim', Color(0xFFEF4444)),
  ];

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) {
      return const Text('Nenhuma nota nos últimos 30 dias.');
    }
    return Column(
      children: [
        for (final (key, label, color) in levels)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 82, child: Text(label, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (distribution[key] ?? 0) / total,
                      minHeight: 12,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${distribution[key] ?? 0}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.position, required this.stats});

  final int position;
  final InstructorStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rating = stats.averageRating == null ? '—' : stats.averageRating!.toStringAsFixed(1).replaceAll('.', ',');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: position == 1 ? Colors.amber : AppTheme.surfaceHigh,
            child: Text('$position', style: TextStyle(fontSize: 12, color: position == 1 ? Colors.black : null)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stats.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${stats.students} alunos · ${stats.sessions30d} treinos'
                  '${stats.pendingSuggestions > 0 ? ' · ${stats.pendingSuggestions} recado(s)' : ''}',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
          const SizedBox(width: 2),
          Text(rating, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.dashboard});

  final ManagerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final price = d.planMonthlyPrice == null ? '' : 'R\$ ${d.planMonthlyPrice!.toStringAsFixed(2).replaceAll('.', ',')}/mês · ';
    final over = d.overPlanLimit;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: over ? Colors.amber : AppTheme.outline),
      ),
      child: ListTile(
        leading: Icon(over ? Icons.warning_amber_rounded : Icons.workspace_premium_rounded,
            color: over ? Colors.amber : Theme.of(context).colorScheme.primary),
        title: Text(d.personal ? 'Seu plano de personal' : 'Plano da academia'),
        subtitle: Text(
          '$price${d.students} de ${d.planIncludedStudents} alunos incluídos'
          '${over ? '\nVocê passou do limite do plano. Fale com a Foco para ajustar.' : ''}',
        ),
        isThreeLine: over,
      ),
    );
  }
}
