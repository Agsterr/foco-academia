import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'gps_diagnostic.dart';
import 'sync_service.dart';

/// Persistência local de eventos de telemetria GPS.
class GpsDiagnosticStore {
  GpsDiagnosticStore._();
  static final instance = GpsDiagnosticStore._();

  Future<Database> get db => AppDatabase.instance.db;

  Future<void> add(GpsDiagnosticEventRecord event) async {
    final database = await db;
    await database.insert('gps_diagnostics', {
      'payload': jsonEncode(event.toJson()),
      'created_at': event.timestamp.toUtc().toIso8601String(),
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> pendingPayloads() async {
    final database = await db;
    final rows = await database.query(
      'gps_diagnostics',
      where: 'synced = 0',
      orderBy: 'id ASC',
      limit: 200,
    );
    return rows.map((r) {
      final payload =
          jsonDecode(r['payload'] as String) as Map<String, dynamic>;
      return {...payload, '_localId': r['id']};
    }).toList();
  }

  Future<void> markSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final id in ids) {
      batch.update(
        'gps_diagnostics',
        {'synced': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> countForSession(String clientSessionId) async {
    final database = await db;
    final rows = await database.query('gps_diagnostics');
    var n = 0;
    for (final r in rows) {
      try {
        final p = jsonDecode(r['payload'] as String) as Map<String, dynamic>;
        if (p['clientSessionId'] == clientSessionId) n++;
      } catch (_) {}
    }
    return n;
  }
}
