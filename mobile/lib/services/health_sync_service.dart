import 'package:shared_preferences/shared_preferences.dart';

import 'cardio_service.dart';

/// Opt-in Health Connect / Apple Health (Fase 4).
///
/// Persistimos a preferência e o payload pronto para sync. A escrita nativa
/// depende do plugin de saúde do SO; nesta versão o app registra a intenção
/// e espelha métricas locais — integração completa com o store do aparelho
/// pode ser ligada sem mudar o fluxo de corrida.
class HealthSyncService {
  HealthSyncService._();
  static final instance = HealthSyncService._();

  static const _optInKey = 'health_sync_opt_in_v1';

  bool _optIn = false;
  bool get isOptedIn => _optIn;

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    _optIn = prefs.getBool(_optInKey) ?? false;
    return _optIn;
  }

  Future<void> setOptIn(bool value) async {
    _optIn = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_optInKey, value);
  }

  /// Após finalizar uma corrida — no-op se o usuário não optou.
  Future<void> syncCompletedSession(CardioSession session) async {
    if (!_optIn) return;
    // Placeholder: em builds com plugin `health`, escrever ExerciseSession /
    // Distance / ActiveEnergyBurned aqui. Mantém o contrato estável.
    await SharedPreferences.getInstance().then((p) async {
      final key = 'health_last_synced_session';
      await p.setString(key, session.id);
    });
  }

  String statusLabel() =>
      _optIn ? 'Sincronização de saúde ativa' : 'Desativada';
}
