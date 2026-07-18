import 'package:shared_preferences/shared_preferences.dart';

/// Controle de uso offline: exige reconexão online a cada 48h.
class OnlineAuthGate {
  OnlineAuthGate._();
  static final instance = OnlineAuthGate._();

  static const maxOfflineHours = 48;
  static const _prefsKey = 'last_successful_online_auth_at';

  Future<DateTime?> lastOnlineAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markOnlineAuthSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, DateTime.now().toUtc().toIso8601String());
  }

  Future<bool> isWithinOfflineWindow() async {
    final last = await lastOnlineAuth();
    if (last == null) return false;
    return DateTime.now().difference(last) < const Duration(hours: maxOfflineHours);
  }

  Future<bool> requiresOnlineReconnect() async => !(await isWithinOfflineWindow());

  Future<Duration?> timeUntilReconnectRequired() async {
    final last = await lastOnlineAuth();
    if (last == null) return null;
    final deadline = last.add(const Duration(hours: maxOfflineHours));
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
