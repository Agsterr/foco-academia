import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_version.dart';
import '../../services/auth_service.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersionName,
    required this.currentVersionCode,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.sha256,
  });

  final String currentVersionName;
  final int currentVersionCode;
  final String latestVersionName;
  final int latestVersionCode;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final String? sha256;

  bool get hasUpdate => latestVersionCode > currentVersionCode;
}

class AppUpdateService {
  AppUpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 5),
            ));

  final Dio _dio;

  static String apkFileName(int versionCode) => 'foco-academia-update-$versionCode.apk';

  Future<String> _apkPathFor(int versionCode) async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/${apkFileName(versionCode)}';
  }

  Future<bool> isApkCached(AppUpdateInfo update) async {
    final file = File(await _apkPathFor(update.latestVersionCode));
    if (!await file.exists()) return false;
    return _verifySha256(file, update.sha256);
  }

  Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AuthService.apiBase}/api/app/version',
      );
      final data = response.data;
      if (data == null) return null;

      return AppUpdateInfo(
        currentVersionName: packageInfo.version,
        currentVersionCode: currentCode,
        latestVersionName: data['versionName'] as String,
        latestVersionCode: (data['versionCode'] as num).toInt(),
        downloadUrl: _absoluteUrl(data['downloadUrl'] as String),
        releaseNotes: data['releaseNotes'] as String?,
        forceUpdate: data['forceUpdate'] as bool? ?? false,
        sha256: data['sha256'] as String?,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  String _absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = AuthService.apiBase.replaceAll(RegExp(r'/$'), '');
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  /// Baixa sempre a latest do servidor. Se uma versão mais nova publicar
  /// no meio do download, descarta o APK antigo e baixa de novo (até 4x).
  Future<AppUpdateInfo> downloadAndInstall(
    AppUpdateInfo update, {
    void Function(double progress)? onProgress,
    void Function(AppUpdateInfo target)? onTargetResolved,
    bool forceDownload = false,
  }) async {
    var target = update;
    var mustRedownload = forceDownload;

    for (var attempt = 0; attempt < 4; attempt++) {
      final latest = await checkForUpdate();
      if (latest == null || !latest.hasUpdate) {
        return target;
      }
      if (latest.latestVersionCode != target.latestVersionCode) {
        mustRedownload = true;
      }
      target = latest;
      onTargetResolved?.call(target);

      final filePath = await _apkPathFor(target.latestVersionCode);
      final cached = !mustRedownload && await isApkCached(target);

      if (!cached) {
        await _purgeStaleApkCaches(keepVersionCode: target.latestVersionCode);
        await _dio.download(
          target.downloadUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total <= 0 || onProgress == null) return;
            onProgress(received / total);
          },
        );
        final file = File(filePath);
        if (!await _verifySha256(file, target.sha256)) {
          await file.delete();
          throw Exception('Arquivo corrompido (checksum inválido)');
        }
      } else if (onProgress != null) {
        onProgress(1);
      }

      // Revalida: se publicaram outra versão enquanto baixávamos, tenta de novo.
      final after = await checkForUpdate();
      if (after != null &&
          after.hasUpdate &&
          after.latestVersionCode > target.latestVersionCode) {
        mustRedownload = true;
        continue;
      }

      await _openInstaller(filePath);
      return target;
    }

    throw Exception('Não foi possível obter a versão mais recente do app');
  }

  Future<void> openCachedInstaller(AppUpdateInfo update) async {
    // Antes de instalar, confirma que ainda é a latest.
    final latest = await checkForUpdate();
    if (latest != null &&
        latest.hasUpdate &&
        latest.latestVersionCode > update.latestVersionCode) {
      await downloadAndInstall(latest, forceDownload: true);
      return;
    }
    if (!await isApkCached(update)) {
      throw Exception('Arquivo de atualização não encontrado');
    }
    await _openInstaller(await _apkPathFor(update.latestVersionCode));
  }

  Future<void> _purgeStaleApkCaches({required int keepVersionCode}) async {
    try {
      final directory = await getTemporaryDirectory();
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isEmpty
            ? entity.path
            : entity.uri.pathSegments.last;
        if (!name.startsWith('foco-academia-update-') || !name.endsWith('.apk')) {
          continue;
        }
        final keepName = apkFileName(keepVersionCode);
        if (name != keepName) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Melhor esforço — não bloqueia o update.
    }
  }

  Future<bool> _verifySha256(File file, String? expectedSha256) async {
    if (expectedSha256 == null || expectedSha256.isEmpty) return true;
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes).toString();
    return digest == expectedSha256;
  }

  Future<void> _openInstaller(String filePath) async {
    final result = await OpenFilex.open(
      filePath,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message ?? 'Não foi possível abrir o instalador');
    }
  }

  static String loginAppVersion() => AppVersion.value;
}
