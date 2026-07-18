import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Modo de treino outdoor escolhido pelo aluno.
enum OutdoorGoalMode {
  /// Sem meta numérica — só GPS e calorias ao vivo.
  free,

  /// Segue o plano do coach (intervalos), se houver.
  coach,

  /// Meta de distância em km.
  distanceKm,

  /// Meta de calorias — o app estima km necessários.
  caloriesKcal,
}

class OutdoorGoal {
  const OutdoorGoal({
    this.mode = OutdoorGoalMode.free,
    this.targetKm,
    this.targetKcal,
    this.assumedSpeedKmh = 5.0,
  });

  final OutdoorGoalMode mode;
  final double? targetKm;
  final int? targetKcal;

  /// Ritmo assumido para converter kcal → km (caminhada moderada).
  final double assumedSpeedKmh;

  bool get hasNumericTarget =>
      (mode == OutdoorGoalMode.distanceKm && targetKm != null && targetKm! > 0) ||
      (mode == OutdoorGoalMode.caloriesKcal && targetKcal != null && targetKcal! > 0);

  String get label {
    return switch (mode) {
      OutdoorGoalMode.free => 'Livre',
      OutdoorGoalMode.coach => 'Plano do coach',
      OutdoorGoalMode.distanceKm => '${targetKm?.toStringAsFixed(1) ?? '?'} km',
      OutdoorGoalMode.caloriesKcal => '${targetKcal ?? '?'} kcal',
    };
  }

  OutdoorGoal copyWith({
    OutdoorGoalMode? mode,
    double? targetKm,
    int? targetKcal,
    double? assumedSpeedKmh,
  }) {
    return OutdoorGoal(
      mode: mode ?? this.mode,
      targetKm: targetKm ?? this.targetKm,
      targetKcal: targetKcal ?? this.targetKcal,
      assumedSpeedKmh: assumedSpeedKmh ?? this.assumedSpeedKmh,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        if (targetKm != null) 'targetKm': targetKm,
        if (targetKcal != null) 'targetKcal': targetKcal,
        'assumedSpeedKmh': assumedSpeedKmh,
      };

  factory OutdoorGoal.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String? ?? 'free';
    final mode = OutdoorGoalMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => OutdoorGoalMode.free,
    );
    return OutdoorGoal(
      mode: mode,
      targetKm: (json['targetKm'] as num?)?.toDouble(),
      targetKcal: (json['targetKcal'] as num?)?.toInt(),
      assumedSpeedKmh: (json['assumedSpeedKmh'] as num?)?.toDouble() ?? 5.0,
    );
  }
}

class OutdoorGoalStore {
  OutdoorGoalStore._();
  static final instance = OutdoorGoalStore._();

  static const _key = 'outdoor_goal_v1';

  Future<OutdoorGoal> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const OutdoorGoal();
    }
    try {
      return OutdoorGoal.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const OutdoorGoal();
    }
  }

  Future<void> save(OutdoorGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(goal.toJson()));
  }
}
