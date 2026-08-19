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

  /// Intervalado próprio: caminhada + corrida até km ou tempo.
  intervals,
}

class OutdoorGoal {
  const OutdoorGoal({
    this.mode = OutdoorGoalMode.free,
    this.targetKm,
    this.targetKcal,
    this.targetMinutes,
    this.walkMin = 2,
    this.runMin = 2,
    this.assumedSpeedKmh = 5.0,
  });

  final OutdoorGoalMode mode;
  final double? targetKm;
  final int? targetKcal;
  final int? targetMinutes;
  final int walkMin;
  final int runMin;

  /// Ritmo assumido para converter kcal → km (caminhada moderada).
  final double assumedSpeedKmh;

  int get walkSec => (walkMin.clamp(1, 30)) * 60;
  int get runSec => (runMin.clamp(1, 30)) * 60;

  bool get hasNumericTarget =>
      (mode == OutdoorGoalMode.distanceKm && targetKm != null && targetKm! > 0) ||
      (mode == OutdoorGoalMode.caloriesKcal && targetKcal != null && targetKcal! > 0) ||
      (mode == OutdoorGoalMode.intervals &&
          ((targetKm != null && targetKm! > 0) ||
              (targetMinutes != null && targetMinutes! > 0)));

  String get label {
    return switch (mode) {
      OutdoorGoalMode.free => 'Livre',
      OutdoorGoalMode.coach => 'Plano do coach',
      OutdoorGoalMode.distanceKm => '${targetKm?.toStringAsFixed(1) ?? '?'} km',
      OutdoorGoalMode.caloriesKcal => '${targetKcal ?? '?'} kcal',
      OutdoorGoalMode.intervals => _intervalLabel,
    };
  }

  String get _intervalLabel {
    final cycle = '$walkMin min caminhada + $runMin min corrida';
    if (targetKm != null && targetKm! > 0) {
      return '$cycle até ${targetKm!.toStringAsFixed(0)} km';
    }
    if (targetMinutes != null && targetMinutes! > 0) {
      return '$cycle por $targetMinutes min';
    }
    return cycle;
  }

  OutdoorGoal copyWith({
    OutdoorGoalMode? mode,
    double? targetKm,
    int? targetKcal,
    int? targetMinutes,
    int? walkMin,
    int? runMin,
    double? assumedSpeedKmh,
    bool clearTargetKm = false,
    bool clearTargetMinutes = false,
  }) {
    return OutdoorGoal(
      mode: mode ?? this.mode,
      targetKm: clearTargetKm ? null : (targetKm ?? this.targetKm),
      targetKcal: targetKcal ?? this.targetKcal,
      targetMinutes:
          clearTargetMinutes ? null : (targetMinutes ?? this.targetMinutes),
      walkMin: walkMin ?? this.walkMin,
      runMin: runMin ?? this.runMin,
      assumedSpeedKmh: assumedSpeedKmh ?? this.assumedSpeedKmh,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        if (targetKm != null) 'targetKm': targetKm,
        if (targetKcal != null) 'targetKcal': targetKcal,
        if (targetMinutes != null) 'targetMinutes': targetMinutes,
        'walkMin': walkMin,
        'runMin': runMin,
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
      targetMinutes: (json['targetMinutes'] as num?)?.toInt(),
      walkMin: (json['walkMin'] as num?)?.toInt() ?? 2,
      runMin: (json['runMin'] as num?)?.toInt() ?? 2,
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
