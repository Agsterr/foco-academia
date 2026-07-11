import 'package:flutter/material.dart';

import '../../data/services/app_update_service.dart';

class AppUpdateListener extends StatefulWidget {
  const AppUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends State<AppUpdateListener>
    with WidgetsBindingObserver {
  final _updateService = AppUpdateService();
  var _checking = false;
  AppUpdateInfo? _forceUpdate;
  var _forceDownloading = false;
  var _forceProgress = 0.0;
  String? _forceError;
  var _forceApkReady = false;
  var _forceAutoDownloadStarted = false;
  int? _readyVersionCode;

  static const _packageConflictHint =
      'Se o Android mostrou "conflito com pacote existente", desinstale o Foco Academia, '
      'baixe o APK no painel admin (App mobile) e instale de novo. '
      'Depois disso, as próximas atualizações pelo app devem funcionar.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUpdate(resumeOnly: true);
    }
  }

  Future<void> _checkUpdate({bool resumeOnly = false}) async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final update = await _updateService.checkForUpdate();
      if (!mounted || update == null || !update.hasUpdate) {
        setState(() {
          _forceUpdate = null;
          _forceApkReady = false;
          _forceAutoDownloadStarted = false;
          _readyVersionCode = null;
        });
        return;
      }

      if (update.forceUpdate) {
        final cached = await _updateService.isApkCached(update);
        final apkReady = cached || _readyVersionCode == update.latestVersionCode;

        setState(() {
          _forceUpdate = update;
          _forceError = null;
          _forceApkReady = apkReady;
          if (cached) {
            _readyVersionCode = update.latestVersionCode;
          }
        });

        final shouldAutoDownload = !resumeOnly &&
            !apkReady &&
            !_forceDownloading &&
            !_forceAutoDownloadStarted;
        if (shouldAutoDownload) {
          _forceAutoDownloadStarted = true;
          await _downloadForceUpdate(update);
        }
        return;
      }

      setState(() {
        _forceUpdate = null;
        _forceApkReady = false;
        _forceAutoDownloadStarted = false;
        _readyVersionCode = null;
      });
      if (!resumeOnly) {
        await _showOptionalDialog(update);
      }
    } catch (_) {
      // Silencioso — app continua offline-first.
    } finally {
      _checking = false;
    }
  }

  Future<void> _downloadForceUpdate(
    AppUpdateInfo update, {
    bool forceDownload = false,
  }) async {
    setState(() {
      _forceDownloading = true;
      _forceProgress = 0;
      _forceError = null;
    });

    try {
      await _updateService.downloadAndInstall(
        update,
        forceDownload: forceDownload,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _forceProgress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _forceApkReady = true;
        _readyVersionCode = update.latestVersionCode;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _forceError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _forceDownloading = false);
      }
    }
  }

  Future<void> _installForceUpdate(AppUpdateInfo update) async {
    setState(() => _forceError = null);
    try {
      await _updateService.openCachedInstaller(update);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _forceError = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showOptionalDialog(AppUpdateInfo update) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var downloading = false;
        var progress = 0.0;
        var apkReady = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> prepareApk({bool forceDownload = false}) async {
              setDialogState(() {
                downloading = true;
                progress = 0;
              });
              try {
                await _updateService.downloadAndInstall(
                  update,
                  forceDownload: forceDownload,
                  onProgress: (value) {
                    setDialogState(() => progress = value);
                  },
                );
                if (!dialogContext.mounted) return;
                setDialogState(() => apkReady = true);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Erro ao atualizar: $error')),
                );
                setDialogState(() {
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
                await _updateService.openCachedInstaller(update);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Erro ao instalar: $error')),
                );
              }
            }

            return AlertDialog(
              title: const Text('Atualização disponível'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versão ${update.latestVersionName} disponível '
                    '(você está na ${update.currentVersionName}).',
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
                    Text(
                      '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}% baixado',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else if (apkReady) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Download concluído. Toque em Instalar para abrir o instalador.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: downloading ? null : () => Navigator.pop(context),
                  child: const Text('Agora não'),
                ),
                if (apkReady)
                  TextButton(
                    onPressed: downloading
                        ? null
                        : () => prepareApk(forceDownload: true),
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final force = _forceUpdate;
    return Stack(
      children: [
        widget.child,
        if (force != null)
          Material(
            color: Colors.black.withValues(alpha: 0.9),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.system_update, size: 48, color: Colors.blue),
                            const SizedBox(height: 16),
                            Text(
                              'Atualização obrigatória',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Versão ${force.latestVersionName} disponível.\n'
                              'Instale para continuar.',
                              textAlign: TextAlign.center,
                            ),
                            if (force.releaseNotes != null &&
                                force.releaseNotes!.trim().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                force.releaseNotes!.trim(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (_forceDownloading) ...[
                              LinearProgressIndicator(
                                value: _forceProgress > 0 ? _forceProgress : null,
                              ),
                              const SizedBox(height: 8),
                              Text('${(_forceProgress * 100).toStringAsFixed(0)}%'),
                            ] else if (_forceApkReady) ...[
                              Text(
                                'Download concluído. Abra o instalador e conclua a instalação.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _packageConflictHint,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => _installForceUpdate(force),
                                icon: const Icon(Icons.install_mobile),
                                label: const Text('Instalar agora'),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _downloadForceUpdate(
                                  force,
                                  forceDownload: true,
                                ),
                                child: const Text('Baixar de novo'),
                              ),
                            ] else
                              FilledButton.icon(
                                onPressed: () => _downloadForceUpdate(force),
                                icon: const Icon(Icons.download),
                                label: const Text('Atualizar agora'),
                              ),
                            if (_forceError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _forceError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
