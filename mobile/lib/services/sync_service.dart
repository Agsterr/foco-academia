import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'auth_service.dart';

class SyncService {
  SyncService._();
  static final instance = SyncService._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'foco_academia.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE pending_sync (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          payload TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    });
    return _db!;
  }

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
    if (rows.isEmpty) return 0;

    final measurements = <Map<String, dynamic>>[];
    final sessions = <Map<String, dynamic>>[];

    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (row['type'] == 'measurement') {
        measurements.add(payload);
      } else if (row['type'] == 'cardio_session') {
        sessions.add(payload);
      }
    }

    await AuthService.instance.post('/api/student/sync', {
      'measurements': measurements,
      'cardioSessions': sessions,
    });

    await database.delete('pending_sync');
    return rows.length;
  }
}
