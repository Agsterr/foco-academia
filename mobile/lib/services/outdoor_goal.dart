import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'interval_duration.dart';

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
    this.walkSec = 120,
    this.runSec = 120,
    this.assumedSpeedKmh = 5.0,
  });

  final OutdoorGoalMode mode;
  final double? targetKm;
  final int? targetKcal;
  final int? targetMinutes;
  final int walkSec;
  final int runSec;

  /// Minutos (pode ser fracionário) — derivado dos segundos.
  double get walkMin => walkSec / 60.0;
  double get runMin => runSec / 60.0;

  /// Ritmo assumido para converter kcal → km (caminhada moderada).
  final double assumedSpeedKmh;

  int get walkSecClamped =>
      walkSec.clamp(IntervalDuration.minSec, IntervalDuration.maxSec);

  int get runSecClamped =>
      runSec.clamp(IntervalDuration.minSec, IntervalDuration.maxSec);

  static int _normalizeSec(int sec) =>
      sec.clamp(IntervalDuration.minSec, IntervalDuration.maxSec);

  bool get hasNumericTarget =>
      (mode == OutdoorGoalMode.distanceKm &&
          targetKm != null &&
          targetKm! > 0) ||
      (mode == OutdoorGoalMode.caloriesKcal &&
          targetKcal != null &&
          targetKcal! > 0) ||
      (mode == OutdoorGoalMode.intervals &&
          ((targetKm != null && targetKm! > 0) ||
              (targetMinutes != null && targetMinutes! > 0)));

  String get label {
    return switch (mode) {
      OutdoorGoalMode.free => 'Livre',
      OutdoorGoalMode.coach => 'Plano do coach',
      OutdoorGoalMode.distanceKm =>
        '${targetKm != null ? formatKm(targetKm!) : '?'} km',
      OutdoorGoalMode.caloriesKcal => '${targetKcal ?? '?'} kcal',
      OutdoorGoalMode.intervals => _intervalLabel,
    };
  }

  String get _intervalLabel {
    final cycle =
        '${IntervalDuration.format(walkSec)} caminhada + ${IntervalDuration.format(runSec)} corrida';
    if (targetKm != null && targetKm! > 0) {
      return '$cycle até ${formatKm(targetKm!)} km';
    }
    if (targetMinutes != null && targetMinutes! > 0) {
      return '$cycle por $targetMinutes min';
    }
    return cycle;
  }

  /// 7 → "7", 7.5 → "7.5", 7.25 → "7.25".
  static String formatKm(double km) {
    final hundredths = (km * 100).round() / 100;
    if (hundredths == hundredths.roundToDouble()) {
      return hundredths.toStringAsFixed(0);
    }
    final tenths = (km * 10).round() / 10;
    if ((km - tenths).abs() < 0.001) {
      return tenths.toStringAsFixed(1);
    }
    return hundredths.toStringAsFixed(2);
  }

  OutdoorGoal copyWith({
    OutdoorGoalMode? mode,
    double? targetKm,
    int? targetKcal,
    int? targetMinutes,
    int? walkSec,
    int? runSec,
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
      walkSec: walkSec != null ? _normalizeSec(walkSec) : this.walkSec,
      runSec: runSec != null ? _normalizeSec(runSec) : this.runSec,
      assumedSpeedKmh: assumedSpeedKmh ?? this.assumedSpeedKmh,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        if (targetKm != null) 'targetKm': targetKm,
        if (targetKcal != null) 'targetKcal': targetKcal,
        if (targetMinutes != null) 'targetMinutes': targetMinutes,
        'walkSec': walkSec,
        'runSec': runSec,
        'assumedSpeedKmh': assumedSpeedKmh,
      };

  factory OutdoorGoal.fromJson(Map<String, dynamic> json) {
    final rawMode = json['mode'] as String? ?? 'free';
    final mode = OutdoorGoalMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => OutdoorGoalMode.free,
    );
    int readSec(String secKey, String minKey, int defaultSec) {
      final rawSec = json[secKey];
      if (rawSec is num) return _normalizeSec(rawSec.round());
      final rawMin = json[minKey];
      if (rawMin is num) return _normalizeSec((rawMin * 60).round());
      return defaultSec;
    }

    return OutdoorGoal(
      mode: mode,
      targetKm: (json['targetKm'] as num?)?.toDouble(),
      targetKcal: (json['targetKcal'] as num?)?.toInt(),
      targetMinutes: (json['targetMinutes'] as num?)?.toInt(),
      walkSec: readSec('walkSec', 'walkMin', 120),
      runSec: readSec('runSec', 'runMin', 120),
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
