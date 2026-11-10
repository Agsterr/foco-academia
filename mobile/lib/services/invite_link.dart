import 'package:flutter/services.dart';

/// Links de convite: `focoacademia://convite/CODIGO` (aberto pela página do link)
/// ou `https://.../convite/CODIGO`.
class InviteLinks {
  InviteLinks._();

  static const _channel = MethodChannel('com.focodev.academia/invite_link');

  /// Código do convite (só letras e números, maiúsculo) ou nulo se não for convite.
  static String? codeFrom(String? link) {
    if (link == null || link.trim().isEmpty) return null;
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    final segments = [if (uri.scheme == 'focoacademia' && uri.host.isNotEmpty) uri.host, ...uri.pathSegments]
        .where((s) => s.isNotEmpty)
        .toList();
    final i = segments.indexOf('convite');
    if (i < 0 || i + 1 >= segments.length) return null;
    final code = normalizeCode(segments[i + 1]);
    return code.length >= 6 ? code : null;
  }

  /// "k7q2m-x9p3t" → "K7Q2MX9P3T".
  static String normalizeCode(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Link com que o app foi aberto, se ainda não foi tratado.
  static Future<String?> takePendingCode() async {
    try {
      return codeFrom(await _channel.invokeMethod<String>('takeInviteLink'));
    } catch (_) {
      return null;
    }
  }

  /// Link aberto com o app já rodando.
  static void listen(void Function(String code) onCode) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'inviteLink') {
        final code = codeFrom(call.arguments as String?);
        if (code != null) onCode(code);
      }
      return null;
    });
  }
}
