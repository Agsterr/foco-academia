/// Texto de erro para mostrar ao usuário: tira o prefixo técnico "Exception: " das mensagens da API.
String errorText(Object error) => error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
