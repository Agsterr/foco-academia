import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Abre telas nativas de bateria (Economia / isenção do app).
class EnergySettingsLauncher {
  EnergySettingsLauncher._();

  static const _channel = MethodChannel('com.focodev.academia/energy_settings');

  /// Vai direto ao interruptor de Economia de energia (como o Strava).
  static Future<bool> openBatterySaverSettings() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('openBatterySaverSettings');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Pedido de isenção de otimização só deste app.
  static Future<bool> openIgnoreBatteryOptimizations() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok =
          await _channel.invokeMethod<bool>('openIgnoreBatteryOptimizations');
      return ok == true;
    } catch (_) {
      return openAppSettings();
    }
  }
}

/// Fluxo de permissões de localização + otimização de bateria (Android).
class LocationPermissionHelper {
  LocationPermissionHelper._();

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

  /// Antes do treino (estilo Strava): se a Economia estiver ligada, leva
  /// direto ao interruptor. Também pede isenção de otimização do app.
  ///
  /// Retorna o status após o fluxo e se pedimos ao usuário desligar a Economia
  /// (para religar ao finalizar).
  static Future<({EnergyThreatStatus status, bool askedToDisablePowerSaver})>
      promptEnergyForWorkout(BuildContext context) async {
    var threats = await readEnergyThreats();
    var askedToDisable = false;
    if (kIsWeb || !Platform.isAndroid) {
      return (status: threats, askedToDisablePowerSaver: false);
    }

    // 1) Economia de energia do SISTEMA — o app NÃO desliga sozinho.
    if (threats.powerSaverOn && context.mounted) {
      askedToDisable = true;
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Desligar economia de energia'),
          content: const Text(
            'A Economia de energia do celular está ligada e atrapalha o GPS '
            'com a tela apagada (a rota fica torta).\n\n'
            'O app não consegue desligar isso sozinho. Toque em '
            '“Desligar agora” para ir direto ao interruptor — como no Strava.\n\n'
            'Ao terminar o treino, podemos te levar de volta para religar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar assim'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desligar agora'),
            ),
          ],
        ),
      );
      if (go == true) {
        await EnergySettingsLauncher.openBatterySaverSettings();
        // Usuário volta das configs — relê o status.
        threats = await readEnergyThreats();
        if (threats.powerSaverOn && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Economia ainda ligada — desligue o interruptor na tela que abriu',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    }

    // 2) Otimização só deste app — aqui o sistema deixa o app pedir isenção.
    if (threats.batteryOptimized && context.mounted) {
      final allow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sem restrições de bateria'),
          content: const Text(
            'Além da Economia, o Android pode restringir só este app.\n\n'
            'Permita “Sem restrições” / “Não otimizar” para o Foco Academia '
            'manter o GPS estável com a tela apagada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Permitir'),
            ),
          ],
        ),
      );
      if (allow == true) {
        final opened =
            await EnergySettingsLauncher.openIgnoreBatteryOptimizations();
        if (!opened) {
          await Permission.ignoreBatteryOptimizations.request();
        }
        threats = await readEnergyThreats();
      }
    }

    return (status: threats, askedToDisablePowerSaver: askedToDisable);
  }

  /// Depois do treino: oferece a religar a Economia (só abre a tela; não liga sozinho).
  static Future<void> promptRestorePowerSaverIfNeeded(
    BuildContext context, {
    required bool askedToDisablePowerSaver,
  }) async {
    if (!askedToDisablePowerSaver || kIsWeb || !Platform.isAndroid) return;
    final threats = await readEnergyThreats();
    // Se ainda está ligada, não precisa “religar”.
    if (threats.powerSaverOn) return;
    if (!context.mounted) return;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Religar economia de energia?'),
        content: const Text(
          'O treino terminou. Quer voltar à tela da Economia de energia '
          'para ligar de novo o interruptor?\n\n'
          'O app não liga automaticamente (o Android não permite), '
          'mas te leva direto ao botão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Deixar desligada'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Religar agora'),
          ),
        ],
      ),
    );
    if (go == true) {
      await EnergySettingsLauncher.openBatterySaverSettings();
    }
  }

  /// Compat: banner / botão de configs no meio do treino.
  static Future<EnergyThreatStatus> promptBatteryOptimizationIfNeeded(
    BuildContext context,
  ) async {
    final r = await promptEnergyForWorkout(context);
    return r.status;
  }
}
