import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Lê peso de balanças BLE com perfil padrão Weight Scale (0x181D).
class BleScaleService {
  BleScaleService._();
  static final instance = BleScaleService._();

  static final Guid weightScaleService =
      Guid('0000181d-0000-1000-8000-00805f9b34fb');
  static final Guid weightMeasurement =
      Guid('00002a9d-0000-1000-8000-00805f9b34fb');

  Future<void> ensurePermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<bool> isBluetoothOn() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      return await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<double?> readWeightKg({
    Duration timeout = const Duration(seconds: 45),
    void Function(String status)? onStatus,
  }) async {
    await ensurePermissions();
    if (!await isBluetoothOn()) {
      throw Exception('Ative o Bluetooth do aparelho');
    }

    onStatus?.call('Procurando balança…');
    BluetoothDevice? target = await _scanForScale();

    if (target == null) {
      throw Exception(
        'Balança não encontrada. Use o registro manual ou uma balança com Bluetooth Weight Scale.',
      );
    }

    onStatus?.call('Conectando em ${target.platformName}…');
    await target.connect(
      license: License.nonprofit,
      timeout: const Duration(seconds: 15),
    );
    try {
      final services = await target.discoverServices();
      BluetoothCharacteristic? char;
      for (final s in services) {
        if (s.serviceUuid == weightScaleService) {
          for (final c in s.characteristics) {
            if (c.characteristicUuid == weightMeasurement) {
              char = c;
              break;
            }
          }
        }
      }
      // Fallback: some stacks expose .uuid
      char ??= _findWeightChar(services);
      if (char == null) {
        throw Exception(
          'Esta balança não usa o perfil padrão. O peso manual continua disponível.',
        );
      }

      onStatus?.call('Suba na balança…');
      final completer = Completer<double>();
      final sub = char.onValueReceived.listen((value) {
        final kg = parseWeightMeasurement(value);
        if (kg != null && !completer.isCompleted) {
          completer.complete(kg);
        }
      });
      await char.setNotifyValue(true);

      try {
        return await completer.future.timeout(
          timeout,
          onTimeout: () =>
              throw Exception('Tempo esgotado — suba na balança'),
        );
      } finally {
        await sub.cancel();
      }
    } finally {
      try {
        await target.disconnect();
      } catch (_) {}
    }
  }

  Future<BluetoothDevice?> _scanForScale() async {
    BluetoothDevice? found;
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final hasService = r.advertisementData.serviceUuids
            .any((u) => u == weightScaleService);
        final name = r.device.platformName.toLowerCase();
        if (hasService ||
            name.contains('scale') ||
            name.contains('balan') ||
            name.contains('weight') ||
            name.contains('mi body') ||
            name.contains('renpho')) {
          found ??= r.device;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [weightScaleService],
        timeout: const Duration(seconds: 10),
      );
      await FlutterBluePlus.isScanning.where((v) => v == false).first;
      if (found != null) return found;

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      await FlutterBluePlus.isScanning.where((v) => v == false).first;
      return found;
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }
  }

  BluetoothCharacteristic? _findWeightChar(List<BluetoothService> services) {
    for (final s in services) {
      for (final c in s.characteristics) {
        final su = s.uuid.toString().toLowerCase();
        final cu = c.uuid.toString().toLowerCase();
        if (su.contains('181d') && cu.contains('2a9d')) {
          return c;
        }
      }
    }
    return null;
  }

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
