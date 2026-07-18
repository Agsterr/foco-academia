import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'gps_tracking_engine.dart';
import 'sync_service.dart';

/// Snapshot de corrida ativa — permite recuperar após kill/crash/reboot.
class ActiveRunSnapshot {
  const ActiveRunSnapshot({
    required this.clientSessionId,
    required this.startedAt,
    required this.distanceMeters,
    required this.elapsedSec,
    required this.points,
    this.serverSessionId,
    this.workoutId,
    this.intervalsJson,
    this.estimatedGapMeters = 0,
    this.elevationGainMeters = 0,
    this.movingElapsedSec = 0,
    this.phaseIndex = 0,
    this.autoPaused = false,
    this.manualPaused = false,
    this.pausedSec = 0,
    this.pauseCount = 0,
    this.splits = const [],
  });

  final String clientSessionId;
  final String? serverSessionId;
  final String? workoutId;
  final String? intervalsJson;
  final DateTime startedAt;
  final double distanceMeters;
  final double estimatedGapMeters;
  final double elevationGainMeters;
  final int elapsedSec;
  final int movingElapsedSec;
  final int phaseIndex;
  final bool autoPaused;
  final bool manualPaused;
  final int pausedSec;
  final int pauseCount;
  final List<TrackedPoint> points;
  final List<KmSplit> splits;

  Map<String, dynamic> toMetaJson() => {
        'clientSessionId': clientSessionId,
        'serverSessionId': serverSessionId,
        'workoutId': workoutId,
        'intervalsJson': intervalsJson,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'distanceMeters': distanceMeters,
        'estimatedGapMeters': estimatedGapMeters,
        'elevationGainMeters': elevationGainMeters,
        'elapsedSec': elapsedSec,
        'movingElapsedSec': movingElapsedSec,
        'phaseIndex': phaseIndex,
        'autoPaused': autoPaused,
        'manualPaused': manualPaused,
        'pausedSec': pausedSec,
        'pauseCount': pauseCount,
        'splits': splits.map((s) => s.toJson()).toList(),
      };

  Map<String, dynamic> toJson() => {
        ...toMetaJson(),
        'points': points.map((p) => p.toJson()).toList(),
      };

  factory ActiveRunSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    final rawSplits = json['splits'] as List<dynamic>? ?? const [];
    return ActiveRunSnapshot(
      clientSessionId: json['clientSessionId'] as String,
      serverSessionId: json['serverSessionId'] as String?,
      workoutId: json['workoutId'] as String?,
      intervalsJson: json['intervalsJson'] as String?,
      startedAt: DateTime.parse(json['startedAt'] as String),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      estimatedGapMeters: (json['estimatedGapMeters'] as num?)?.toDouble() ?? 0,
      elevationGainMeters:
          (json['elevationGainMeters'] as num?)?.toDouble() ?? 0,
      elapsedSec: (json['elapsedSec'] as num?)?.toInt() ?? 0,
      movingElapsedSec: (json['movingElapsedSec'] as num?)?.toInt() ??
          (json['elapsedSec'] as num?)?.toInt() ??
          0,
      phaseIndex: (json['phaseIndex'] as num?)?.toInt() ?? 0,
      autoPaused: json['autoPaused'] as bool? ?? false,
      manualPaused: json['manualPaused'] as bool? ?? false,
      pausedSec: (json['pausedSec'] as num?)?.toInt() ?? 0,
      pauseCount: (json['pauseCount'] as num?)?.toInt() ?? 0,
      points: rawPoints
          .map((e) => TrackedPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      splits: rawSplits
          .map((e) => KmSplit.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ActiveRunStore {
  ActiveRunStore._();
  static final instance = ActiveRunStore._();

  static const activeFlagKey = 'active_run_v1';

  DateTime? _lastPersistAt;
  int _lastPersistedSeq = -1;

  Future<Database> get db => AppDatabase.instance.db;

  Future<ActiveRunSnapshot?> load() async {
    final database = await db;
    final rows = await database.query('active_run', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    try {
      final payload =
          jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;

      // Preferir pontos na tabela dedicada (v3+).
      final pointRows = await database.query(
        'active_run_points',
        orderBy: 'sequence_num ASC',
      );
      if (pointRows.isNotEmpty) {
        payload['points'] = pointRows
            .map((r) => jsonDecode(r['payload'] as String))
            .toList();
      }

      final snapshot = ActiveRunSnapshot.fromJson(payload);
      if (snapshot.points.isNotEmpty) {
        _lastPersistedSeq = snapshot.points.last.sequenceNum;
      } else {
        _lastPersistedSeq = -1;
      }
      return snapshot;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(
    ActiveRunSnapshot snapshot, {
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastPersistAt != null &&
        now.difference(_lastPersistAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastPersistAt = now;
    final database = await db;

        await database.insert(
      'active_run',
      {
        'id': 1,
        'payload': jsonEncode(snapshot.toMetaJson()),
        'updated_at': now.toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Append / upsert incremental dos pontos.
    final batch = database.batch();
    for (final p in snapshot.points) {
      if (p.sequenceNum <= _lastPersistedSeq) continue;
      batch.insert(
        'active_run_points',
        {
          'sequence_num': p.sequenceNum,
          'payload': jsonEncode(p.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    if (snapshot.points.isNotEmpty) {
      _lastPersistedSeq = snapshot.points.last.sequenceNum;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activeFlagKey, true);
  }

  Future<void> clear() async {
    _lastPersistAt = null;
    _lastPersistedSeq = -1;
    final database = await db;
    await database.delete('active_run_points');
    await database.delete('active_run');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(activeFlagKey, false);
  }

  Future<bool> hasActiveFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(activeFlagKey) ?? false;
  }

  Future<int> pointCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM active_run_points',
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
