import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/services/app_update_service.dart';

/// UI compartilhada para checagem / download de atualização do APK.
class AppUpdatePrompt {
  AppUpdatePrompt._();

  static Future<String> installedVersionLabel() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  /// Retorna mensagem amigável do resultado (para SnackBar) ou null se abriu diálogo.
  static Future<String?> checkAndPrompt(
    BuildContext context, {
    required AppUpdateService service,
    bool manual = false,
  }) async {
    final update = await service.checkForUpdate();
    if (!context.mounted) return null;

    if (update == null) {
      return 'Nenhuma versão publicada no servidor';
    }

    final local = '${update.currentVersionName}+${update.currentVersionCode}';
    final remote = '${update.latestVersionName}+${update.latestVersionCode}';

    if (!update.hasUpdate) {
      if (update.forceUpdate) {
        return 'App atualizado ($local). Force update está ligado no servidor, '
            'mas só aparece quando houver APK mais novo que o instalado. Servidor: $remote.';
      }
      return 'App atualizado — você está na $local (servidor: $remote)';
    }

    if (update.forceUpdate) {
      await showUpdateDialog(context, service: service, update: update, force: true);
      return null;
    }

    if (manual) {
      await showUpdateDialog(context, service: service, update: update, force: false);
      return null;
    }

    await showUpdateDialog(context, service: service, update: update, force: false);
    return null;
  }

  static Future<void> showUpdateDialog(
    BuildContext context, {
    required AppUpdateService service,
    required AppUpdateInfo update,
    required bool force,
  }) async {
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: !force,
      builder: (dialogContext) {
        var downloading = false;
        var progress = 0.0;
        var apkReady = false;
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> prepareApk({bool forceDownload = false}) async {
              setDialogState(() {
                downloading = true;
                progress = 0;
                error = null;
              });
              try {
                await service.downloadAndInstall(
                  update,
                  forceDownload: forceDownload,
                  onProgress: (value) {
                    setDialogState(() => progress = value);
                  },
                );
                if (!dialogContext.mounted) return;
                setDialogState(() => apkReady = true);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                  downloading = false;
                  progress = 0;
                });
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => downloading = false);
                }
              }
            }

            Future<void> install() async {
              if (!apkReady) {
                await prepareApk();
                if (!dialogContext.mounted || !apkReady) return;
              }
              try {
                await service.openCachedInstaller(update);
              } catch (e) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  error = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return PopScope(
              canPop: !force,
              child: AlertDialog(
                title: Text(force ? 'Atualização obrigatória' : 'Atualização disponível'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Servidor: ${update.latestVersionName}+${update.latestVersionCode}\n'
                      'Seu app: ${update.currentVersionName}+${update.currentVersionCode}',
                    ),
                    if (update.releaseNotes != null &&
                        update.releaseNotes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(update.releaseNotes!.trim()),
                    ],
                    if (downloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress > 0 ? progress : null),
                      const SizedBox(height: 8),
                      Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}% baixado'),
                    ] else if (apkReady) ...[
                      const SizedBox(height: 12),
                      const Text('Download concluído. Toque em Instalar.'),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
                actions: [
                  if (!force)
                    TextButton(
                      onPressed: downloading ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Agora não'),
                    ),
                  if (apkReady)
                    TextButton(
                      onPressed: downloading ? null : () => prepareApk(forceDownload: true),
                      child: const Text('Baixar de novo'),
                    ),
                  FilledButton(
                    onPressed: downloading ? null : install,
                    child: Text(
                      downloading
                          ? 'Baixando...'
                          : apkReady
                              ? 'Instalar'
                              : 'Atualizar',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
