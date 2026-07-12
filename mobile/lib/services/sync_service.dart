import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'auth_service.dart';
import 'gps_diagnostic_store.dart';

/// Banco local compartilhado (fila de sync + corrida ativa).
class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'foco_academia.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_sync (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE active_run (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            payload TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE active_run_points (
            sequence_num INTEGER PRIMARY KEY,
            payload TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE gps_diagnostics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS active_run (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              payload TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS active_run_points (
              sequence_num INTEGER PRIMARY KEY,
              payload TEXT NOT NULL
            )
          ''');
          final rows =
              await db.query('active_run', where: 'id = 1', limit: 1);
          if (rows.isNotEmpty) {
            try {
              final payload = jsonDecode(rows.first['payload'] as String)
                  as Map<String, dynamic>;
              final points = payload['points'] as List<dynamic>? ?? const [];
              final batch = db.batch();
              for (final raw in points) {
                final map = raw as Map<String, dynamic>;
                final seq = (map['sequenceNum'] as num?)?.toInt() ?? 0;
                batch.insert(
                  'active_run_points',
                  {
                    'sequence_num': seq,
                    'payload': jsonEncode(map),
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
              await batch.commit(noResult: true);
              payload.remove('points');
              await db.update(
                'active_run',
                {'payload': jsonEncode(payload)},
                where: 'id = 1',
              );
            } catch (_) {}
          }
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS gps_diagnostics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              synced INTEGER NOT NULL DEFAULT 0
            )
          ''');
        }
      },
    );
    return _db!;
  }
}

class SyncService {
  SyncService._();
  static final instance = SyncService._();

  Future<Database> get db => AppDatabase.instance.db;

  Future<void> queue(String type, Map<String, dynamic> payload) async {
    final database = await db;
    await database.insert('pending_sync', {
      'type': type,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> syncAll() async {
    final database = await db;
    final rows = await database.query('pending_sync', orderBy: 'id ASC');

    final measurements = <Map<String, dynamic>>[];
    final sessions = <Map<String, dynamic>>[];

    for (final row in rows) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (row['type'] == 'measurement') {
        measurements.add(payload);
      } else if (row['type'] == 'cardio_session') {
        sessions.add(payload);
      }
    }

    final diagRows = await GpsDiagnosticStore.instance.pendingPayloads();
    final diagnostics = <Map<String, dynamic>>[];
    final diagIds = <int>[];
    for (final d in diagRows) {
      final id = d.remove('_localId') as int?;
      if (id != null) diagIds.add(id);
      diagnostics.add(d);
    }

    if (measurements.isEmpty && sessions.isEmpty && diagnostics.isEmpty) {
      return 0;
    }

    await AuthService.instance.post('/api/student/sync', {
      'measurements': measurements,
      'cardioSessions': sessions,
      'diagnostics': diagnostics,
    });

    if (rows.isNotEmpty) {
      await database.delete('pending_sync');
    }
    await GpsDiagnosticStore.instance.markSynced(diagIds);
    return rows.length + diagnostics.length;
  }

  Future<int> pendingCount() async {
    final database = await db;
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM pending_sync',
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
