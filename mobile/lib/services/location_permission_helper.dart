import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fluxo de permissões de localização + otimização de bateria (Android).
class LocationPermissionHelper {
  LocationPermissionHelper._();

  static const _batteryPromptKey = 'battery_opt_prompted_v1';
  static const _locationRationaleKey = 'location_rationale_shown_v1';

  /// Status atuais para a tela Debug GPS.
  static Future<Map<String, String>> debugPermissionSnapshot() async {
    final loc = await Geolocator.checkPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    var battery = 'n/a';
    if (!kIsWeb && Platform.isAndroid) {
      final s = await Permission.ignoreBatteryOptimizations.status;
      battery = s.isGranted ? 'ignored' : 'optimized';
    }
    return {
      'location': loc.name,
      'serviceEnabled': enabled.toString(),
      'battery': battery,
    };
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
      await prefs.setBool(_locationRationaleKey, true);
    }

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

  /// Na primeira corrida, pede para ignorar otimização de bateria (Android).
  static Future<void> promptBatteryOptimizationIfNeeded(
    BuildContext context,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_batteryPromptKey) == true) {
      // Já perguntou: se ainda otimizado, só avisa levemente.
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Otimização de bateria ativa — o GPS pode falhar em segundo plano',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      await prefs.setBool(_batteryPromptKey, true);
      return;
    }

    if (!context.mounted) return;
    final allow = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Precisão do GPS'),
        content: const Text(
          'Seu celular pode interromper o GPS em segundo plano.\n\n'
          'Para garantir um rastreamento preciso, permita que este aplicativo '
          'ignore a otimização de bateria.\n\n'
          'Isso vale apenas para o Foco Academia.',
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

    await prefs.setBool(_batteryPromptKey, true);

    if (allow == true) {
      final result = await Permission.ignoreBatteryOptimizations.request();
      if (!result.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem essa permissão, a precisão em segundo plano pode cair',
            ),
          ),
        );
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Otimização de bateria ativa — a precisão poderá ser reduzida',
          ),
        ),
      );
    }
  }
}
