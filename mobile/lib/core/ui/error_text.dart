import 'dart:async';

/// Texto de erro para mostrar ao usuário, em português claro:
/// - tira o prefixo técnico "Exception: " das mensagens da API;
/// - falta de internet, demora e resposta estranha do servidor viram frases que dizem o que fazer;
/// - "Erro 500" (sem mensagem do servidor) vira um aviso de problema temporário.
String errorText(Object error) {
  if (error is TimeoutException) {
    return 'A conexão está lenta e o servidor não respondeu. Tente de novo em instantes.';
  }
  if (error is FormatException) {
    return 'O servidor respondeu algo inesperado. Tente de novo em instantes.';
  }
  final text = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
  if (text.contains('SocketException') ||
      text.contains('ClientException') ||
      text.contains('Failed host lookup') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset') ||
      text.contains('HandshakeException')) {
    return 'Sem conexão com a internet. Verifique e tente novamente.';
  }
  final status = RegExp(r'^Erro (\d{3})$').firstMatch(text);
  if (status != null) {
    final code = int.parse(status.group(1)!);
    if (code >= 500) return 'O servidor está com problema agora. Tente de novo em alguns minutos.';
    if (code == 403) return 'Você não tem permissão para fazer isso.';
    if (code == 429) return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    return 'Não foi possível concluir (erro $code). Tente de novo.';
  }
  return text;
}
