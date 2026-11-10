/// `true` no build enviado à Google Play (`--dart-define=PLAY_STORE=true`).
///
/// Na loja não pode haver atualização por APK externo nem pedido de
/// localização em segundo plano (a Play atualiza o app e o serviço em
/// primeiro plano já mantém o GPS ligado durante o treino).
const bool kPlayStoreBuild = bool.fromEnvironment('PLAY_STORE');
