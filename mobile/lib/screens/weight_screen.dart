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

  Future<void> _connectScale() async {
    setState(() {
      _saving = true;
      _status = 'Iniciando Bluetooth…';
    });
    try {
      final kg = await BleScaleService.instance.readWeightKg(
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (kg == null) {
        setState(() => _status = 'Leitura cancelada');
        return;
      }
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
                          'Compatível com balanças no perfil Weight Scale. '
                          'Suba na balança quando pedir.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _saving ? null : _connectScale,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: Text(_saving ? 'Aguardando…' : 'Conectar balança'),
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
                          'e importe aqui. A sincronização direta OAuth com '
                          'cada marca ainda não está disponível.',
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
