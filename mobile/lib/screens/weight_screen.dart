import 'package:flutter/material.dart';

import '../services/ble_scale_service.dart';
import '../services/weight_service.dart';
import '../services/watch_import_service.dart';
import '../services/auth_service.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final _weightCtrl = TextEditingController();
  List<BodyMeasurement> _items = [];
  bool _loading = true;
  bool _saving = false;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    BleScaleService.instance.stopScan();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await WeightService.instance.list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } on SessionExpiredException {
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveManual() async {
    final value = double.tryParse(_weightCtrl.text.replaceAll(',', '.'));
    if (value == null || value < 20 || value > 500) {
      setState(() => _status = 'Informe um peso válido (kg)');
      return;
    }
    setState(() => _saving = true);
    try {
      await WeightService.instance.add(weightKg: value, source: 'STUDENT');
      _weightCtrl.clear();
      setState(() => _status = 'Peso $value kg salvo');
      await _load();
    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openScaleSheet() async {
    final kg = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => const _ScaleScanSheet(),
    );
    if (kg == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final rounded = double.parse(kg.toStringAsFixed(1));
      await WeightService.instance.add(
        weightKg: rounded,
        notes: 'Medição via balança Bluetooth',
        source: 'SCALE_BLE',
      );
      setState(() => _status = 'Peso $rounded kg salvo da balança');
      await _load();
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _importWatch() async {
    setState(() {
      _saving = true;
      _status = 'Selecione o arquivo GPX ou TCX do relógio…';
    });
    try {
      final msg = await WatchImportService.instance.pickAndImport();
      setState(() => _status = msg);
    } catch (e) {
      setState(() => _status = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartItems = [..._items].reversed.take(16).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolução e peso'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                _WeightSparkline(items: chartItems),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Balança Bluetooth',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Funciona com balanças OKOK/Ocoq (Chipsea) e Weight Scale. '
                          'Pise na balança — ela aparece na lista sem parear no Android.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _openScaleSheet,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(
                            _saving ? 'Salvando…' : 'Buscar / conectar balança',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Registrar peso (manual)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Peso (kg)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _saving ? null : _saveManual,
                          child: const Text('Salvar'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Relógio de corrida',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Exporte GPX ou TCX do Garmin, Coros, Amazfit, etc. '
                          'e importe aqui.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _importWatch,
                          icon: const Icon(Icons.watch),
                          label: const Text('Importar GPX / TCX'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    style: const TextStyle(color: Colors.lightGreenAccent),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Histórico',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_items.isEmpty)
                  const Text(
                    'Nenhuma medição ainda.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ..._items.take(20).map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${m.weightKg.toStringAsFixed(1)} kg'),
                        subtitle: Text(
                          '${_fmtDate(m.recordedAt)} · ${_sourceLabel(m.source)}',
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'SCALE_BLE':
        return 'Balança';
      case 'WATCH':
      case 'IMPORT':
        return 'Relógio/import';
      default:
        return 'Manual';
    }
  }
}

class _ScaleScanSheet extends StatefulWidget {
  const _ScaleScanSheet();

  @override
  State<_ScaleScanSheet> createState() => _ScaleScanSheetState();
}

class _ScaleScanSheetState extends State<_ScaleScanSheet> {
  List<BleScaleCandidate> _devices = [];
  String _status = 'Preparando Bluetooth…';
  String? _error;
  String? _selectedId;
  double? _liveKg;
  bool _stable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    BleScaleService.instance.stopScan();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _busy = true;
      _status = 'Iniciando…';
    });
    try {
      final kg = await BleScaleService.instance.waitForStableWeight(
        preferRemoteId: _selectedId,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
        onDevices: (list) {
          if (mounted) setState(() => _devices = list);
        },
        onLive: (sample) {
          if (_selectedId != null && sample.remoteId != _selectedId) return;
          if (mounted) {
            setState(() {
              _liveKg = sample.kg;
              _stable = sample.stable;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(kg);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('cancelada')) return;
      setState(() {
        _error = msg;
        _busy = false;
      });
    }
  }

  Future<void> _selectDevice(BleScaleCandidate d) async {
    setState(() {
      _selectedId = d.remoteId;
      _status = 'Aguardando peso de ${d.name}… Pise na balança.';
      _error = null;
      _busy = true;
    });
    await BleScaleService.instance.stopScan(cancelWait: true);
    try {
      final kg = await BleScaleService.instance.waitForStableWeight(
        preferRemoteId: d.remoteId,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
        onDevices: (list) {
          if (mounted) setState(() => _devices = list);
        },
        onLive: (sample) {
          if (sample.remoteId != d.remoteId) return;
          if (mounted) {
            setState(() {
              _liveKg = sample.kg;
              _stable = sample.stable;
            });
          }
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(kg);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.contains('cancelada')) return;
      setState(() {
        _error = msg;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Conectar balança',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            if (_liveKg != null) ...[
              const SizedBox(height: 12),
              Text(
                '${_liveKg!.toStringAsFixed(1)} kg'
                '${_stable ? ' ✓' : ' …'}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: _stable ? Colors.lightGreenAccent : Colors.white,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _start,
                child: const Text('Tentar de novo'),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Dispositivos próximos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Toque na sua balança se aparecer. Se nada listar, pise nela '
              'e aguarde alguns segundos.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _devices.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhum dispositivo ainda…\nPise na balança agora.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final d = _devices[i];
                        final selected = d.remoteId == _selectedId;
                        return ListTile(
                          selected: selected,
                          leading: Icon(
                            d.likelyScale
                                ? Icons.monitor_weight
                                : Icons.bluetooth,
                            color: d.likelyScale
                                ? Colors.lightBlueAccent
                                : Colors.white54,
                          ),
                          title: Text(d.name),
                          subtitle: Text(
                            [
                              'Sinal ${d.rssi} dBm',
                              if (d.hint != null) d.hint!,
                              if (d.liveWeightKg != null)
                                '${d.liveWeightKg!.toStringAsFixed(1)} kg',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: d.likelyScale
                              ? const Chip(
                                  label: Text('Balança?', style: TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                )
                              : null,
                          onTap: () => _selectDevice(d),
                        );
                      },
                    ),
            ),
            TextButton(
              onPressed: () {
                BleScaleService.instance.stopScan();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightSparkline extends StatelessWidget {
  const _WeightSparkline({required this.items});

  final List<BodyMeasurement> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Sem dados para o gráfico ainda.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    final weights = items.map((e) => e.weightKg).toList();
    final first = weights.first;
    final last = weights.last;
    final delta = last - first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Evolução',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${last.toStringAsFixed(1)} kg',
                  style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: delta < 0
                        ? Colors.lightGreenAccent
                        : delta > 0
                            ? Colors.orangeAccent
                            : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _SparklinePainter(weights),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 0.01 ? 1.0 : (max - min);
    final paint = Paint()
      ..color = const Color(0xFF60A5FA)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    final dot = Paint()..color = const Color(0xFF93C5FD);
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
