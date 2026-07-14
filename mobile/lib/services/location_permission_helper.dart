import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de energia que costuma matar GPS com a tela apagada.
class EnergyThreatStatus {
  const EnergyThreatStatus({
    required this.batteryOptimized,
    required this.powerSaverOn,
    this.batteryLevel,
  });

  /// App ainda está sujeito à otimização de bateria do Android.
  final bool batteryOptimized;

  /// Economia de energia / Battery Saver do sistema ligado.
  final bool powerSaverOn;

  final int? batteryLevel;

  bool get threatensBackgroundGps => batteryOptimized || powerSaverOn;

  String? get shortWarning {
    if (powerSaverOn && batteryOptimized) {
      return 'Economia de energia + otimização ativas — GPS pode falhar com tela apagada';
    }
    if (powerSaverOn) {
      return 'Economia de energia ligada — desligue para GPS estável com tela apagada';
    }
    if (batteryOptimized) {
      return 'Otimização de bateria ativa — permita “sem restrições” para este app';
    }
    return null;
  }
}

/// Fluxo de permissões de localização + otimização de bateria (Android).
class LocationPermissionHelper {
  LocationPermissionHelper._();

  static const _batteryPromptKey = 'battery_opt_prompted_v1';
  static const _locationRationaleKey = 'location_rationale_shown_v1';
  static final _battery = Battery();

  /// Status atuais para a tela Debug GPS / diagnósticos.
  static Future<Map<String, String>> debugPermissionSnapshot() async {
    final loc = await Geolocator.checkPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    var battery = 'n/a';
    var powerSaver = 'n/a';
    var level = 'n/a';
    if (!kIsWeb && Platform.isAndroid) {
      final s = await Permission.ignoreBatteryOptimizations.status;
      battery = s.isGranted ? 'ignored' : 'optimized';
      try {
        final saver = await _battery.isInBatterySaveMode;
        powerSaver = saver ? 'on' : 'off';
        level = '${await _battery.batteryLevel}';
      } catch (_) {}
    }
    return {
      'location': loc.name,
      'serviceEnabled': enabled.toString(),
      'battery': battery,
      'powerSaver': powerSaver,
      'batteryLevel': level,
    };
  }

  /// Lê ameaças de energia (otimização do app + economia do sistema).
  static Future<EnergyThreatStatus> readEnergyThreats() async {
    if (kIsWeb || !Platform.isAndroid) {
      return const EnergyThreatStatus(
        batteryOptimized: false,
        powerSaverOn: false,
      );
    }
    var optimized = true;
    var saver = false;
    int? level;
    try {
      final s = await Permission.ignoreBatteryOptimizations.status;
      optimized = !s.isGranted;
    } catch (_) {}
    try {
      saver = await _battery.isInBatterySaveMode;
      level = await _battery.batteryLevel;
    } catch (_) {}
    return EnergyThreatStatus(
      batteryOptimized: optimized,
      powerSaverOn: saver,
      batteryLevel: level,
    );
  }

  /// Solicita: rationale → notificação → while-in-use → always → GPS ligado.
  static Future<bool> ensureTrackingPermissions(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_locationRationaleKey) != true) {
      if (!context.mounted) return false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Localização para o treino'),
          content: const Text(
            'Precisamos da sua localização precisa para gravar a rota, '
            'distância e ritmo durante a corrida ou caminhada.\n\n'
            'Com a tela apagada, usamos localização em segundo plano '
            'somente enquanto o treino estiver ativo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (ok != true) return false;
    }
    await prefs.setBool(_locationRationaleKey, true);

    if (!kIsWeb && Platform.isAndroid) {
      final notif = await Permission.notification.request();
      if (!notif.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ative notificações para gravar o GPS com a tela apagada',
            ),
          ),
        );
      }
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização necessária')),
        );
      }
      return false;
    }

    // Android 10+ / iOS: pedir "sempre" com explicação (segundo plano / tela apagada).
    if (!kIsWeb &&
        (Platform.isAndroid || Platform.isIOS) &&
        permission == LocationPermission.whileInUse) {
      if (!context.mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Localização em segundo plano'),
          content: const Text(
            'Para gravar a rota com a tela apagada ou o app minimizado, '
            'permita o acesso à localização o tempo todo.\n\n'
            'Usamos isso apenas durante o treino outdoor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar sem isso'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Permitir'),
            ),
          ],
        ),
      );

      if (proceed == true) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.whileInUse) {
          final always = await Permission.locationAlways.request();
          if (!always.isGranted && context.mounted) {
            final open = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Abrir configurações'),
                content: const Text(
                  'Escolha "Permitir o tempo todo" (ou Always) nas '
                  'configurações de localização deste aplicativo.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Agora não'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Abrir configurações'),
                  ),
                ],
              ),
            );
            if (open == true) {
              await Geolocator.openAppSettings();
            }
          }
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem localização em segundo plano, a precisão pode cair '
              'com a tela apagada',
            ),
          ),
        );
      }
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative o GPS do aparelho')),
        );
      }
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  /// Antes de cada treino: avisa economia de energia e pede isenção de otimização.
  /// Não “esquece” depois de um “Agora não” — se ainda estiver otimizado, pergunta de novo.
  static Future<EnergyThreatStatus> promptBatteryOptimizationIfNeeded(
    BuildContext context,
  ) async {
    final threats = await readEnergyThreats();
    if (kIsWeb || !Platform.isAndroid) return threats;

    if (threats.powerSaverOn && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Economia de energia ligada'),
          content: const Text(
            'O modo Economia de energia (Battery Saver) do celular '
            'reduz ou atrasa o GPS com a tela apagada — a rota pode '
            'ficar torta mesmo com o app em segundo plano.\n\n'
            'Desligue a economia de energia durante o treino outdoor '
            '(Configurações → Bateria).',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }

    if (!threats.batteryOptimized) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_batteryPromptKey, true);
      return threats;
    }

    if (!context.mounted) return threats;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bateria restringindo o GPS'),
        content: const Text(
          'Seu celular ainda está otimizando (restringindo) este app.\n\n'
          'Com a tela apagada isso costuma cortar ou atrasar o GPS e '
          'a rota fica errada.\n\n'
          'Permita que o Foco Academia ignore a otimização de bateria '
          '(ou use “Sem restrições” / “Não otimizar”).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar assim'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permitir'),
          ),
        ],
      ),
    );

    if (allow == true) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (!result.isGranted && context.mounted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Abrir configurações de bateria'),
            content: const Text(
              'Em alguns celulares (Samsung, Xiaomi, Motorola) o pedido '
              'automático não basta.\n\n'
              'Abra as configs do app → Bateria → Sem restrições / '
              'Não otimizar / Autostart permitido.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Agora não'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abrir configs'),
              ),
            ],
          ),
        );
        if (open == true) {
          await openAppSettings();
        }
      }
    }

    return readEnergyThreats();
  }
}
