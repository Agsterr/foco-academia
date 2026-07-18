import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cardio_service.dart';

/// Biblioteca local de treinos prescritos pelo coach (ativos e anteriores).
class CardioWorkoutLibrary {
  CardioWorkoutLibrary._();
  static final instance = CardioWorkoutLibrary._();

  static const _key = 'cardio_workout_library_v1';
  static const _maxItems = 30;

  Future<void> mergeFromRemote(List<CardioWorkout> workouts) async {
    if (workouts.isEmpty) return;
    final existing = await listAll();
    final byId = {for (final w in existing) w.id: w};
    for (final w in workouts) {
      if (w.intervals.isNotEmpty) {
        byId[w.id] = w;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final trimmed = merged.take(_maxItems).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(trimmed.map((w) => w.toCacheJson()).toList()),
    );
  }

  Future<void> saveOne(CardioWorkout workout) async {
    if (workout.intervals.isEmpty) return;
    final all = await listAll();
    final without = all.where((w) => w.id != workout.id).toList();
    without.insert(0, workout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(without.take(_maxItems).map((w) => w.toCacheJson()).toList()),
    );
  }

  Future<List<CardioWorkout>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => CardioWorkout.fromCacheJson(Map<String, dynamic>.from(e)))
          .where((w) => w.intervals.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<CardioWorkout?> findById(String id) async {
    final all = await listAll();
    for (final w in all) {
      if (w.id == id) return w;
    }
    return null;
  }
}
