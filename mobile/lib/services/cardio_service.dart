import 'dart:convert';

import 'auth_service.dart';
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
  });

  final String id;
  final String title;
  final String type;
  final List<CardioInterval> intervals;

  factory CardioWorkout.fromJson(Map<String, dynamic> json) {
    return CardioWorkout(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Treino outdoor',
      type: json['type'] as String? ?? 'RUN',
      intervals: parseIntervals(json['intervalsJson'] ?? json['intervals']),
    );
  }

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
      final data = await AuthService.instance.get('/api/student/cardio-workouts/active');
      return CardioWorkout.fromJson(data);
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      // Sem treino ativo (400) ou rede — modo livre.
      return null;
    }
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
