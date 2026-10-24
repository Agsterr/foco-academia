/// Diz se já é hora de salvar de novo o progresso do treino.
///
/// Compara com o último save em vez de exigir um segundo exato (10, 20, 30…):
/// com a tela apagada o Android atrasa o relógio do app e esses segundos
/// "redondos" podiam ser pulados por muito tempo — se o app fosse fechado,
/// o treino voltava para o último save e perdia distância.
bool checkpointDue({
  required int? lastSec,
  required int nowSec,
  required int everySec,
}) {
  if (nowSec <= 0) return false;
  if (lastSec == null || nowSec < lastSec) return nowSec >= everySec;
  return nowSec - lastSec >= everySec;
}
