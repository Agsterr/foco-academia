import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'login_screen.dart';

class CalorieStatsScreen extends StatefulWidget {
  const CalorieStatsScreen({super.key});

  @override
  State<CalorieStatsScreen> createState() => _CalorieStatsScreenState();
}

class _CalorieStatsScreenState extends State<CalorieStatsScreen> {
  CalorieStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await ProfileService.instance.getCalorieStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? Center(child: Text(_error ?? 'Sem dados'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('Quilômetros', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Tile('Total', '${s.totalKm.toStringAsFixed(1)} km')),
                          const SizedBox(width: 8),
                          Expanded(child: _Tile('Hoje', '${s.kmToday.toStringAsFixed(1)} km')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Tile('7 dias', '${s.kmLast7Days.toStringAsFixed(1)} km')),
                          const SizedBox(width: 8),
                          Expanded(child: _Tile('30 dias', '${s.kmLast30Days.toStringAsFixed(1)} km')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Tile('12 meses', '${s.kmLast12Months.toStringAsFixed(1)} km')),
                          const SizedBox(width: 8),
                          Expanded(child: _Tile('Corridas', '${s.cardioSessions}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Calorias', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Tile('Hoje', '${s.caloriesToday} kcal')),
                          const SizedBox(width: 8),
                          Expanded(child: _Tile('7 dias', '${s.caloriesLast7Days} kcal')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _Tile('30 dias', '${s.caloriesLast30Days} kcal')),
                          const SizedBox(width: 8),
                          Expanded(child: _Tile('12 meses', '${s.caloriesLast12Months} kcal')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Km por dia (7 dias)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...s.weekly.map((b) {
                        final maxKm = s.weekly.map((e) => e.km).fold<double>(0, (a, v) => v > a ? v : a);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(b.label, style: const TextStyle(color: Colors.white70)),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: maxKm > 0 ? (b.km / maxKm).clamp(0.0, 1.0) : 0,
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.lightBlueAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '${b.km.toStringAsFixed(1)} km',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text('Km por mês', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ...s.monthly.reversed.take(6).map((b) {
                        final maxKm = s.monthly.map((e) => e.km).fold<double>(0, (a, v) => v > a ? v : a);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(b.label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: maxKm > 0 ? (b.km / maxKm).clamp(0.0, 1.0) : 0,
                                  minHeight: 10,
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.tealAccent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 52,
                                child: Text(
                                  '${b.km.toStringAsFixed(1)} km',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text('Histórico de distâncias', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (s.recentDistances.isEmpty)
                        const Text(
                          'Nenhuma corrida/caminhada registrada ainda.',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        )
                      else
                        ...s.recentDistances.map(
                          (r) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.dateLabel,
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${r.distanceKm.toStringAsFixed(2)} km',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ),
                                    if (r.caloriesKcal != null)
                                      Text(
                                        '${r.caloriesKcal} kcal',
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text('Ranking pessoal', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _Tile('Maior distância', '${s.maxDistanceKm.toStringAsFixed(2)} km'),
                      const SizedBox(height: 8),
                      _Tile('Maior gasto calórico', '${s.maxCaloriesSingleSession} kcal'),
                      const SizedBox(height: 8),
                      _Tile('Maior duração', '${s.maxDurationMinutes} min'),
                      const SizedBox(height: 8),
                      _Tile('Sequência', '${s.currentStreakDays} dias'),
                      const SizedBox(height: 12),
                      Text(
                        s.estimateDisclaimer,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
