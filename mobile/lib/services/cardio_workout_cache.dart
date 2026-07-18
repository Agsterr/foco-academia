import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cardio_service.dart';
import 'cardio_workout_library.dart';

/// Cache local do último treino outdoor ativo (intervalos do coach).
class CardioWorkoutCache {
  CardioWorkoutCache._();
  static final instance = CardioWorkoutCache._();

  static const _key = 'active_cardio_workout_v1';

  Future<void> save(CardioWorkout workout) async {
    if (workout.intervals.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'id': workout.id,
        'title': workout.title,
        'type': workout.type,
        'active': workout.active,
        'createdAt': workout.createdAt.toUtc().toIso8601String(),
        'intervals': workout.intervals
            .map((i) => {'phase': i.phase, 'durationSec': i.durationSec})
            .toList(),
      }),
    );
    await CardioWorkoutLibrary.instance.saveOne(workout);
  }

  Future<CardioWorkout?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final intervals = parseIntervals(json['intervals']);
      if (intervals.isEmpty) return null;
      return CardioWorkout(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Treino outdoor',
        type: json['type'] as String? ?? 'INTERVAL',
        intervals: intervals,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
