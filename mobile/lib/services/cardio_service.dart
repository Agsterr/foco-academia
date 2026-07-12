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
      intervals: parseIntervals(json['intervalsJson'] as String?),
    );
  }
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

List<CardioInterval> parseIntervals(String? json) {
  if (json == null || json.isEmpty) return [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => CardioInterval.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
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
