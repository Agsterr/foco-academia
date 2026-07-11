import 'package:flutter/material.dart';

import '../../data/services/app_update_service.dart';
import 'app_update_prompt.dart';

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
    AppUpdateInfo? pendingForceDownload;
    try {
      final update = await _updateService.checkForUpdate();
      if (!mounted) return;

      if (update == null || !update.hasUpdate) {
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
          pendingForceDownload = update;
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
        // Libera o lock antes do diálogo (usuário pode demorar).
        _checking = false;
        await AppUpdatePrompt.showUpdateDialog(
          context,
          service: _updateService,
          update: update,
          force: false,
        );
      }
    } catch (_) {
      // Silencioso no auto-check — app continua offline-first.
    } finally {
      _checking = false;
    }

    if (pendingForceDownload != null && mounted) {
      await _downloadForceUpdate(pendingForceDownload);
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
                              'Servidor: ${force.latestVersionName}+${force.latestVersionCode}\n'
                              'Seu app: ${force.currentVersionName}+${force.currentVersionCode}\n\n'
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
