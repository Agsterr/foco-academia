import 'package:flutter/material.dart';

import '../core/ui/insets.dart';
import '../services/ble_scale_service.dart';

/// Abre a folha que procura a balança Bluetooth e devolve o peso estável em kg (ou null se cancelar).
Future<double?> showScaleScanSheet(BuildContext context) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => const ScaleScanSheet(),
  );
}

class ScaleScanSheet extends StatefulWidget {
  const ScaleScanSheet({super.key});

  @override
  State<ScaleScanSheet> createState() => ScaleScanSheetState();
}

class ScaleScanSheetState extends State<ScaleScanSheet> {
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
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + systemBottomInset(context)),
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
