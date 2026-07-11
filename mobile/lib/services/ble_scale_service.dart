import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Dispositivo visto no scan BLE.
class BleScaleCandidate {
  const BleScaleCandidate({
    required this.remoteId,
    required this.name,
    required this.rssi,
    required this.likelyScale,
    this.liveWeightKg,
    this.stable = false,
    this.hint,
  });

  final String remoteId;
  final String name;
  final int rssi;
  final bool likelyScale;
  final double? liveWeightKg;
  final bool stable;
  final String? hint;
}

class ScaleWeightSample {
  const ScaleWeightSample({
    required this.kg,
    required this.stable,
    required this.remoteId,
    required this.name,
  });

  final double kg;
  final bool stable;
  final String remoteId;
  final String name;
}

/// Balanças BLE:
/// - OKOK / Chipsea ("Ocoq"): peso no anúncio (sem pareamento GATT).
/// - Perfil padrão Weight Scale (0x181D): conexão GATT.
class BleScaleService {
  BleScaleService._();
  static final instance = BleScaleService._();

  static final Guid weightScaleService =
      Guid('0000181d-0000-1000-8000-00805f9b34fb');
  static final Guid weightMeasurement =
      Guid('00002a9d-0000-1000-8000-00805f9b34fb');

  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, BleScaleCandidate> _seen = {};
  Completer<double>? _waitCompleter;

  Future<void> ensurePermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      final denied = statuses.entries
          .where((e) => !e.value.isGranted && !e.value.isLimited)
          .map((e) => e.key.toString())
          .toList();
      if (denied.isNotEmpty) {
        throw Exception(
          'Permissões necessárias: Bluetooth e localização. '
          'Ative nas configurações do celular.',
        );
      }
    } else if (Platform.isIOS) {
      await Permission.bluetooth.request();
    }
  }

  Future<bool> isBluetoothOn() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      final state = await FlutterBluePlus.adapterState.first;
      if (state == BluetoothAdapterState.on) return true;
      // Tenta pedir para ligar (Android).
      try {
        await FlutterBluePlus.turnOn();
        return await FlutterBluePlus.adapterState
                .first
                .timeout(const Duration(seconds: 8)) ==
            BluetoothAdapterState.on;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> stopScan({bool cancelWait = true}) async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;
    if (cancelWait) {
      final waiting = _waitCompleter;
      if (waiting != null && !waiting.isCompleted) {
        waiting.completeError(Exception('Busca cancelada'));
      }
      _waitCompleter = null;
    }
  }

  /// Scan contínuo; atualiza [onDevices] e [onSample] (peso OKOK ao vivo).
  Future<void> startDiscovery({
    required void Function(List<BleScaleCandidate> devices) onDevices,
    void Function(ScaleWeightSample sample)? onSample,
    void Function(String status)? onStatus,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await stopScan(cancelWait: false);
    _seen.clear();
    await ensurePermissions();
    if (!await isBluetoothOn()) {
      throw Exception('Ative o Bluetooth do aparelho e tente de novo');
    }

    onStatus?.call(
      'Procurando… Pise na balança para ela aparecer (OKOK/Ocoq não precisa parear).',
    );

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        final name = _displayName(r);
        final parsed = parseAdvertisementWeight(r.advertisementData);
        final likely = _isLikelyScale(r, parsed != null);
        final prev = _seen[id];
        _seen[id] = BleScaleCandidate(
          remoteId: id,
          name: name,
          rssi: r.rssi,
          likelyScale: likely || (prev?.likelyScale ?? false),
          liveWeightKg: parsed?.kg ?? prev?.liveWeightKg,
          stable: parsed?.stable ?? prev?.stable ?? false,
          hint: parsed != null
              ? (parsed.stable ? 'Peso estável' : 'Medindo…')
              : (likely ? 'Possível balança' : null),
        );
        if (parsed != null) {
          onSample?.call(
            ScaleWeightSample(
              kg: parsed.kg,
              stable: parsed.stable,
              remoteId: id,
              name: name,
            ),
          );
        }
      }
      final list = _seen.values.toList()
        ..sort((a, b) {
          final la = a.likelyScale ? 0 : 1;
          final lb = b.likelyScale ? 0 : 1;
          if (la != lb) return la.compareTo(lb);
          return b.rssi.compareTo(a.rssi);
        });
      onDevices(list);
    });

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );
  }

  /// Aguarda peso estável de qualquer balança OKOK no ar, ou GATT se [preferRemoteId].
  Future<double> waitForStableWeight({
    String? preferRemoteId,
    Duration timeout = const Duration(seconds: 45),
    void Function(String status)? onStatus,
    void Function(List<BleScaleCandidate> devices)? onDevices,
    void Function(ScaleWeightSample sample)? onLive,
  }) async {
    final completer = Completer<double>();
    _waitCompleter = completer;
    Timer? watchdog;

    Future<void> finish(double kg) async {
      if (!completer.isCompleted) completer.complete(kg);
    }

    await startDiscovery(
      onStatus: onStatus,
      onDevices: onDevices ?? (_) {},
      onSample: (sample) {
        onLive?.call(sample);
        if (preferRemoteId != null && sample.remoteId != preferRemoteId) {
          return;
        }
        onStatus?.call(
          sample.stable
              ? 'Peso estável: ${sample.kg.toStringAsFixed(1)} kg'
              : 'Medindo: ${sample.kg.toStringAsFixed(1)} kg…',
        );
        if (sample.stable && sample.kg >= 5 && sample.kg <= 300) {
          finish(sample.kg);
        }
      },
    );

    // Se o usuário escolheu um dispositivo com perfil Weight Scale, tenta GATT em paralelo.
    if (preferRemoteId != null) {
      unawaited(() async {
        try {
          final kg = await _readGattWeight(
            preferRemoteId,
            onStatus: onStatus,
          );
          if (kg != null) await finish(kg);
        } catch (e) {
          onStatus?.call(e.toString().replaceFirst('Exception: ', ''));
        }
      }());
    }

    watchdog = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'Tempo esgotado. Pise na balança com o Bluetooth ligado e '
            'aguarde o peso estabilizar, ou registre o peso manualmente.',
          ),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      watchdog?.cancel();
      if (identical(_waitCompleter, completer)) {
        _waitCompleter = null;
      }
      await stopScan(cancelWait: false);
    }
  }

  Future<double?> _readGattWeight(
    String remoteId, {
    void Function(String status)? onStatus,
  }) async {
    final device = BluetoothDevice.fromId(remoteId);
    onStatus?.call('Conectando em ${_safeName(device)}…');
    await device.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 12),
    );
    try {
      final services = await device.discoverServices();
      final char = _findWeightChar(services);
      if (char == null) return null;

      onStatus?.call('Suba na balança (perfil Weight Scale)…');
      final completer = Completer<double>();
      final sub = char.onValueReceived.listen((value) {
        final kg = parseWeightMeasurement(value);
        if (kg != null && !completer.isCompleted) {
          completer.complete(kg);
        }
      });
      await char.setNotifyValue(true);
      try {
        return await completer.future.timeout(const Duration(seconds: 30));
      } finally {
        await sub.cancel();
      }
    } finally {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  String _displayName(ScanResult r) {
    final n = r.device.platformName.trim();
    if (n.isNotEmpty) return n;
    final adv = r.advertisementData.advName.trim();
    if (adv.isNotEmpty) return adv;
    final id = r.device.remoteId.str;
    return 'Dispositivo ${id.length > 8 ? id.substring(id.length - 8) : id}';
  }

  String _safeName(BluetoothDevice d) {
    final n = d.platformName.trim();
    return n.isEmpty ? d.remoteId.str : n;
  }

  bool _isLikelyScale(ScanResult r, bool hasWeightPayload) {
    if (hasWeightPayload) return true;
    final name =
        '${r.device.platformName} ${r.advertisementData.advName}'.toLowerCase();
    if (name.contains('scale') ||
        name.contains('balan') ||
        name.contains('weight') ||
        name.contains('chipsea') ||
        name.contains('okok') ||
        name.contains('ocoq') ||
        name.contains('mi body') ||
        name.contains('renpho') ||
        name.contains('yoda') ||
        name.contains('cf3') ||
        name.contains('qn-')) {
      return true;
    }
    return r.advertisementData.serviceUuids.any((u) => u == weightScaleService);
  }

  BluetoothCharacteristic? _findWeightChar(List<BluetoothService> services) {
    for (final s in services) {
      for (final c in s.characteristics) {
        final su = s.uuid.toString().toLowerCase();
        final cu = c.uuid.toString().toLowerCase();
        if ((su.contains('181d') && cu.contains('2a9d')) ||
            (c.characteristicUuid == weightMeasurement)) {
          return c;
        }
      }
    }
    return null;
  }

  /// Extrai peso de anúncios OKOK/Chipsea (e variantes).
  static ({double kg, bool stable})? parseAdvertisementWeight(
    AdvertisementData adv,
  ) {
    for (final entry in adv.manufacturerData.entries) {
      final parsed = parseOkokManufacturerBytes(entry.value);
      if (parsed != null) return parsed;
      final withId = <int>[
        entry.key & 0xff,
        (entry.key >> 8) & 0xff,
        ...entry.value,
      ];
      final parsed2 = parseOkokManufacturerBytes(withId);
      if (parsed2 != null) return parsed2;
    }
    for (final entry in adv.serviceData.entries) {
      final parsed = parseOkokManufacturerBytes(entry.value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static ({double kg, bool stable})? parseOkokManufacturerBytes(List<int> raw) {
    return _parseOkokBytes(raw);
  }

  static ({double kg, bool stable})? _parseOkokBytes(List<int> raw) {
    if (raw.isEmpty) return null;
    final bytes = raw.map((e) => e & 0xff).toList();

    // Formato clássico CA … (openScale #496): peso em décimos → /10
    final ca = bytes.indexOf(0xca);
    if (ca >= 0 && bytes.length >= ca + 12) {
      final finalFlag = bytes[ca + 8];
      final w = (bytes[ca + 10] << 8) | bytes[ca + 11];
      final kg = w / 10.0;
      if (_plausibleKg(kg)) {
        return (kg: kg, stable: finalFlag == 0x01);
      }
    }

    // Formato C0 (openScale #950 / OKOK): peso em centésimos → /100
    // 81.50 kg → 0x1FD6 = 8150. NÃO usar /10 (6.8 virava 68).
    for (var i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] != 0xc0) continue;
      final w = (bytes[i + 2] << 8) | bytes[i + 3];
      final status = bytes.length > i + 8 ? bytes[i + 8] : 0x24;
      final kg = w / 100.0;
      if (_plausibleKg(kg)) {
        final stable =
            status == 0x25 || status == 0x21 || status == 0x01 || (status & 0x01) == 1;
        return (kg: kg, stable: stable);
      }
    }

    return null;
  }

  static bool _plausibleKg(double kg) => kg >= 5 && kg <= 300;

  static double? parseWeightMeasurement(List<int> bytes) {
    if (bytes.length < 3) return null;
    final flags = bytes[0];
    final imperial = (flags & 0x01) != 0;
    final raw = bytes[1] | (bytes[2] << 8);
    final value = raw / 200.0;
    if (imperial) return value * 0.45359237;
    return value;
  }
}
