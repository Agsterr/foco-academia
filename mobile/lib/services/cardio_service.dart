import 'dart:convert';

import 'auth_service.dart';
import 'cardio_workout_cache.dart';
import 'cardio_workout_library.dart';
import 'gps_tracking_engine.dart';

class CardioInterval {
  const CardioInterval({required this.phase, required this.durationSec});

  final String phase; // RUN | WALK
  final int durationSec;

  factory CardioInterval.fromJson(Map<String, dynamic> json) {
    return CardioInterval(
      phase: (json['phase'] as String? ?? 'WALK').toUpperCase(),
      durationSec: (json['durationSec'] as num?)?.toInt() ?? 60,
    );
  }

  bool get isRun => phase == 'RUN';
}

class CardioWorkout {
  const CardioWorkout({
    required this.id,
    required this.title,
    required this.type,
    this.intervals = const [],
    this.active = false,
    DateTime? createdAt,
  })  : createdAt = createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final String title;
  final String type;
  final List<CardioInterval> intervals;
  final bool active;
  final DateTime createdAt;

  factory CardioWorkout.fromJson(Map<String, dynamic> json) {
    final intervals = parseIntervals(json['intervals'] ?? json['intervalsJson']);
    return CardioWorkout(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Treino outdoor',
      type: json['type'] as String? ?? 'RUN',
      intervals: intervals,
      active: json['active'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  factory CardioWorkout.fromCacheJson(Map<String, dynamic> json) {
    final intervals = parseIntervals(json['intervals']);
    return CardioWorkout(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Treino outdoor',
      type: json['type'] as String? ?? 'INTERVAL',
      intervals: intervals,
      active: json['active'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'title': title,
        'type': type,
        'active': active,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'intervals': intervals
            .map((i) => {'phase': i.phase, 'durationSec': i.durationSec})
            .toList(),
      };

  /// Ex.: "2 min caminhada + 3 min corrida · 15 rodadas"
  String get intervalsSummary => summarizeIntervals(intervals);
}

class CardioSession {
  const CardioSession({
    required this.id,
    this.workoutId,
    this.workoutTitle,
    this.startedAt,
    this.completedAt,
    this.distanceMeters,
    this.avgSpeedKmh,
    this.elapsedMs,
    this.caloriesKcal,
    this.gpsQualityScore,
    this.gpsQualityLabel,
    this.routePoints = const [],
  });

  final String id;
  final String? workoutId;
  final String? workoutTitle;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? distanceMeters;
  final double? avgSpeedKmh;
  final int? elapsedMs;
  final int? caloriesKcal;
  final double? gpsQualityScore;
  final String? gpsQualityLabel;
  final List<TrackedPoint> routePoints;

  factory CardioSession.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['routePoints'] as List<dynamic>? ?? const [];
    return CardioSession(
      id: json['id'] as String,
      workoutId: json['workoutId'] as String?,
      workoutTitle: json['workoutTitle'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
      elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
      caloriesKcal: (json['caloriesKcal'] as num?)?.toInt(),
      gpsQualityScore: (json['gpsQualityScore'] as num?)?.toDouble(),
      gpsQualityLabel: json['gpsQualityLabel'] as String?,
      routePoints: rawPoints
          .map((e) => TrackedPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Aceita `intervalsJson` (String JSON) ou lista já decodificada da API.
List<CardioInterval> parseIntervals(Object? raw) {
  if (raw == null) return [];
  try {
    final List<dynamic> list;
    if (raw is String) {
      if (raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      list = decoded;
    } else if (raw is List) {
      list = raw;
    } else {
      return [];
    }
    return list
        .whereType<Map>()
        .map((e) => CardioInterval.fromJson(Map<String, dynamic>.from(e)))
        .where((i) => i.durationSec > 0)
        .toList();
  } catch (_) {
    return [];
  }
}

/// Resumo legível da sequência prescrita pelo coach.
String summarizeIntervals(List<CardioInterval> intervals) {
  if (intervals.isEmpty) return '';
  final walk = intervals.where((i) => !i.isRun).toList();
  final run = intervals.where((i) => i.isRun).toList();
  final walkSec = walk.isNotEmpty ? walk.first.durationSec : 0;
  final runSec = run.isNotEmpty ? run.first.durationSec : 0;
  final rounds = (intervals.length + 1) ~/ 2;
  final parts = <String>[];
  if (walkSec > 0) {
    parts.add('${_formatMinutes(walkSec)} caminhada');
  }
  if (runSec > 0) {
    parts.add('${_formatMinutes(runSec)} corrida');
  }
  if (parts.isEmpty) {
    return '$rounds fases';
  }
  final cycle = parts.join(' + ');
  if (rounds <= 1) return cycle;
  return '$cycle · $rounds rodadas';
}

String _formatMinutes(int sec) {
  if (sec <= 0) return '0 min';
  if (sec % 60 == 0) return '${sec ~/ 60} min';
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m == 0) return '${s}s';
  return '$m:${s.toString().padLeft(2, '0')} min';
}

class CardioService {
  CardioService._();
  static final instance = CardioService._();

  Future<CardioWorkout?> getActiveWorkout() async {
    try {
      final data =
          await AuthService.instance.getOptional('/api/student/cardio-workouts/active');
      if (data == null) {
        return null;
      }
      final workout = CardioWorkout.fromJson(data);
      if (workout.intervals.isNotEmpty) {
        await CardioWorkoutCache.instance.save(workout);
        await CardioWorkoutLibrary.instance.saveOne(workout);
      }
      return workout;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return CardioWorkoutCache.instance.load();
    }
  }

  /// Todos os treinos prescritos pelo coach (ativos e anteriores).
  Future<List<CardioWorkout>> listWorkouts() async {
    try {
      final raw =
          await AuthService.instance.getList('/api/student/cardio-workouts');
      final workouts = raw
          .whereType<Map>()
          .map((e) => CardioWorkout.fromJson(Map<String, dynamic>.from(e)))
          .where((w) => w.intervals.isNotEmpty)
          .toList();
      await CardioWorkoutLibrary.instance.mergeFromRemote(workouts);
      return workouts;
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return CardioWorkoutLibrary.instance.listAll();
    }
  }

  /// Carrega treino ativo ou cache local (intervalos do coach).
  Future<CardioWorkout?> getActiveWorkoutWithCache() async {
    final remote = await getActiveWorkout();
    if (remote != null && remote.intervals.isNotEmpty) return remote;
    final library = await CardioWorkoutLibrary.instance.listAll();
    if (library.isNotEmpty) return library.first;
    final cached = await CardioWorkoutCache.instance.load();
    if (cached != null) return cached;
    return remote;
  }

  Future<CardioSession> startSession({String? workoutId, required String clientSessionId}) async {
    final data = await AuthService.instance.post('/api/student/cardio-sessions/start', {
      if (workoutId != null) 'workoutId': workoutId,
      'clientSessionId': clientSessionId,
    });
    return CardioSession.fromJson(data);
  }

  Future<void> completeSession({
    required String sessionId,
    required double distanceMeters,
    required double avgSpeedKmh,
    required int elapsedMs,
    int pausedMs = 0,
    int pauseCount = 0,
    int? caloriesKcal,
    double? gpsQualityScore,
    String? gpsQualityLabel,
    String? gpsAlgorithmVersion,
    String? filterVersion,
    String? kalmanVersion,
    String? distanceVersion,
    String? caloriesVersion,
    String? gpsConfigSnapshot,
    required List<Map<String, dynamic>> points,
  }) async {
    await AuthService.instance.post('/api/student/cardio-sessions/$sessionId/complete', {
      'distanceMeters': distanceMeters,
      'avgSpeedKmh': avgSpeedKmh,
      'elapsedMs': elapsedMs,
      'pausedMs': pausedMs,
      'pauseCount': pauseCount,
      if (caloriesKcal != null) 'caloriesKcal': caloriesKcal,
      if (gpsQualityScore != null) 'gpsQualityScore': gpsQualityScore,
      if (gpsQualityLabel != null) 'gpsQualityLabel': gpsQualityLabel,
      if (gpsAlgorithmVersion != null) 'gpsAlgorithmVersion': gpsAlgorithmVersion,
      if (filterVersion != null) 'filterVersion': filterVersion,
      if (kalmanVersion != null) 'kalmanVersion': kalmanVersion,
      if (distanceVersion != null) 'distanceVersion': distanceVersion,
      if (caloriesVersion != null) 'caloriesVersion': caloriesVersion,
      if (gpsConfigSnapshot != null) 'gpsConfigSnapshot': gpsConfigSnapshot,
      'points': points,
    });
  }

  /// Backup incremental na nuvem durante a corrida.
  Future<void> backupRoutePoints({
    required String sessionId,
    required List<Map<String, dynamic>> points,
  }) async {
    if (points.isEmpty) return;
    await AuthService.instance.post(
      '/api/student/cardio-sessions/$sessionId/points',
      {'points': points},
    );
  }

  Future<List<CardioSession>> listSessions() async {
    final list =
        await AuthService.instance.getList('/api/student/cardio-sessions');
    return list
        .map((e) => CardioSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
