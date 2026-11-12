import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../data/home_workouts.dart';

/// Um treino em casa concluído.
class HomeWorkoutLog {
  const HomeWorkoutLog({
    required this.workoutId,
    required this.title,
    required this.level,
    required this.at,
    required this.seconds,
    required this.kcal,
    required this.exercises,
    required this.xp,
  });

  final String workoutId;
  final String title;
  final String level;
  final DateTime at;

  /// Tempo total do treino, com os descansos.
  final int seconds;
  final int kcal;

  /// Exercícios feitos (cada passo conta uma vez).
  final int exercises;
  final int xp;

  Map<String, dynamic> toJson() => {
        'workoutId': workoutId,
        'title': title,
        'level': level,
        'at': at.toIso8601String(),
        'seconds': seconds,
        'kcal': kcal,
        'exercises': exercises,
        'xp': xp,
      };

  static HomeWorkoutLog? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return HomeWorkoutLog(
        workoutId: json['workoutId'] as String,
        title: json['title'] as String,
        level: json['level'] as String,
        at: DateTime.parse(json['at'] as String),
        seconds: (json['seconds'] as num).toInt(),
        kcal: (json['kcal'] as num).toInt(),
        exercises: (json['exercises'] as num).toInt(),
        xp: (json['xp'] as num).toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Nível do jogador: sobe com o XP ganho em cada treino.
class PlayerLevel {
  const PlayerLevel({required this.level, required this.title, required this.xpInto, required this.xpNeeded});

  final int level;
  final String title;

  /// XP já acumulado dentro do nível atual.
  final int xpInto;

  /// XP que o nível atual exige para chegar ao próximo.
  final int xpNeeded;

  double get progress => xpNeeded == 0 ? 1 : (xpInto / xpNeeded).clamp(0.0, 1.0);

  static const titles = ['Iniciante', 'Persistente', 'Dedicado', 'Guerreiro', 'Atleta', 'Elite', 'Lenda'];

  /// Nível 1 → 2 pede 100 XP, 2 → 3 pede 150, e assim por diante (+50 a cada nível).
  static PlayerLevel fromXp(int xp) {
    var level = 1;
    var left = xp < 0 ? 0 : xp;
    var need = 100;
    while (left >= need) {
      left -= need;
      level++;
      need += 50;
    }
    return PlayerLevel(level: level, title: titles[(level - 1).clamp(0, titles.length - 1)], xpInto: left, xpNeeded: need);
  }
}

class HomeBadge {
  const HomeBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.earned,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool Function(HomeWorkoutStats s) earned;
}

final homeBadges = <HomeBadge>[
  HomeBadge(
    id: 'first',
    title: 'Primeiro passo',
    description: 'Conclua seu primeiro treino em casa',
    icon: Icons.flag_rounded,
    color: AppTheme.green,
    earned: (s) => s.totalWorkouts >= 1,
  ),
  HomeBadge(
    id: 'five',
    title: 'Pegando o ritmo',
    description: 'Conclua 5 treinos',
    icon: Icons.directions_run_rounded,
    color: AppTheme.cyan,
    earned: (s) => s.totalWorkouts >= 5,
  ),
  HomeBadge(
    id: 'twentyfive',
    title: 'Hábito criado',
    description: 'Conclua 25 treinos',
    icon: Icons.verified_rounded,
    color: AppTheme.violet,
    earned: (s) => s.totalWorkouts >= 25,
  ),
  HomeBadge(
    id: 'streak3',
    title: 'Três dias seguidos',
    description: 'Treine 3 dias em sequência',
    icon: Icons.local_fire_department_rounded,
    color: AppTheme.orange,
    earned: (s) => s.bestStreak >= 3,
  ),
  HomeBadge(
    id: 'streak7',
    title: 'Semana perfeita',
    description: 'Treine 7 dias em sequência',
    icon: Icons.whatshot_rounded,
    color: AppTheme.red,
    earned: (s) => s.bestStreak >= 7,
  ),
  HomeBadge(
    id: 'kcal500',
    title: 'Queimador',
    description: 'Gaste 500 kcal no total',
    icon: Icons.bolt_rounded,
    color: AppTheme.amber,
    earned: (s) => s.totalKcal >= 500,
  ),
  HomeBadge(
    id: 'kcal2500',
    title: 'Fornalha',
    description: 'Gaste 2.500 kcal no total',
    icon: Icons.fireplace_rounded,
    color: AppTheme.pink,
    earned: (s) => s.totalKcal >= 2500,
  ),
  HomeBadge(
    id: 'ex100',
    title: 'Mil e uma repetições',
    description: 'Faça 100 exercícios',
    icon: Icons.fitness_center_rounded,
    color: AppTheme.blue,
    earned: (s) => s.totalExercises >= 100,
  ),
  HomeBadge(
    id: 'extreme',
    title: 'Sem medo',
    description: 'Conclua um treino de nível Extremo',
    icon: Icons.military_tech_rounded,
    color: AppTheme.accent,
    earned: (s) => s.logs.any((l) => l.level == HomeLevel.extremo.name),
  ),
];

/// Números e conquistas calculados a partir do histórico de treinos em casa.
class HomeWorkoutStats {
  HomeWorkoutStats(List<HomeWorkoutLog> logs, {DateTime? now})
      : logs = List.unmodifiable(logs),
        now = now ?? DateTime.now();

  final List<HomeWorkoutLog> logs;
  final DateTime now;

  /// Meta semanal de treinos (segunda a domingo).
  static const weeklyGoal = 4;

  int get totalWorkouts => logs.length;
  int get totalKcal => logs.fold(0, (a, l) => a + l.kcal);
  int get totalSeconds => logs.fold(0, (a, l) => a + l.seconds);
  int get totalExercises => logs.fold(0, (a, l) => a + l.exercises);
  int get xp => logs.fold(0, (a, l) => a + l.xp);
  PlayerLevel get playerLevel => PlayerLevel.fromXp(xp);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Set<DateTime> get _days => {for (final l in logs) _day(l.at)};

  bool _isToday(DateTime d) => _day(d) == _day(now);

  int get kcalToday => logs.where((l) => _isToday(l.at)).fold(0, (a, l) => a + l.kcal);
  int get minutesToday => (logs.where((l) => _isToday(l.at)).fold(0, (a, l) => a + l.seconds) / 60).round();

  /// Dias seguidos com treino até hoje. Se hoje ainda não treinou, a sequência de ontem continua valendo.
  int get streak {
    final days = _days;
    var day = _day(now);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(day)) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Maior sequência de dias seguidos de todos os tempos.
  int get bestStreak {
    final sorted = _days.toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in sorted) {
      run = prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  /// Calorias dos últimos 7 dias, do mais antigo (índice 0) até hoje (índice 6).
  List<int> get kcalLast7Days {
    final today = _day(now);
    return List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day - (6 - i));
      return logs.where((l) => _day(l.at) == d).fold(0, (a, l) => a + l.kcal);
    });
  }

  /// Treinos feitos nesta semana (segunda a domingo).
  int get workoutsThisWeek {
    final today = _day(now);
    final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    return logs.where((l) => !_day(l.at).isBefore(monday)).length;
  }

  Set<String> get earnedBadgeIds => {for (final b in homeBadges) if (b.earned(this)) b.id};
}

/// XP de um treino: base do nível + 3 por exercício + 1 por minuto.
int homeWorkoutXp(HomeLevel level, int exercises, int seconds) => level.baseXp + exercises * 3 + seconds ~/ 60;

/// Guarda o histórico de treinos em casa no próprio aparelho (funciona sem internet).
class HomeWorkoutProgress {
  HomeWorkoutProgress._();
  static final instance = HomeWorkoutProgress._();

  static const _key = 'home_workout_logs_v1';
  static const _maxLogs = 1000;

  Future<List<HomeWorkoutLog>> loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(HomeWorkoutLog.fromJson).whereType<HomeWorkoutLog>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<HomeWorkoutStats> loadStats() async => HomeWorkoutStats(await loadLogs());

  /// Registra um treino concluído e devolve o que mudou (XP, nível, conquistas novas).
  Future<HomeWorkoutResult> record(HomeWorkoutLog log) async {
    final before = HomeWorkoutStats(await loadLogs());
    final logs = [...before.logs, log];
    final trimmed = logs.length > _maxLogs ? logs.sublist(logs.length - _maxLogs) : logs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode([for (final l in trimmed) l.toJson()]));
    final after = HomeWorkoutStats(trimmed);
    final newBadges = [
      for (final b in homeBadges)
        if (!before.earnedBadgeIds.contains(b.id) && after.earnedBadgeIds.contains(b.id)) b,
    ];
    return HomeWorkoutResult(
      log: log,
      before: before,
      after: after,
      newBadges: newBadges,
      leveledUp: after.playerLevel.level > before.playerLevel.level,
    );
  }
}

class HomeWorkoutResult {
  const HomeWorkoutResult({
    required this.log,
    required this.before,
    required this.after,
    required this.newBadges,
    required this.leveledUp,
  });

  final HomeWorkoutLog log;
  final HomeWorkoutStats before;
  final HomeWorkoutStats after;
  final List<HomeBadge> newBadges;
  final bool leveledUp;
}
