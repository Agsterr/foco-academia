import '../services/auth_service.dart';

const weekDayOrder = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const weekDayLabels = {
  'MONDAY': 'Segunda',
  'TUESDAY': 'Terça',
  'WEDNESDAY': 'Quarta',
  'THURSDAY': 'Quinta',
  'FRIDAY': 'Sexta',
  'SATURDAY': 'Sábado',
  'SUNDAY': 'Domingo',
};

const weekDayShort = {
  'MONDAY': 'Seg',
  'TUESDAY': 'Ter',
  'WEDNESDAY': 'Qua',
  'THURSDAY': 'Qui',
  'FRIDAY': 'Sex',
  'SATURDAY': 'Sáb',
  'SUNDAY': 'Dom',
};

const ratingLabels = {
  'MUITO_BOM': 'Muito bom',
  'BOM': 'Bom',
  'FACIL': 'Fácil',
  'RUIM': 'Ruim',
  'MUITO_RUIM': 'Muito ruim',
};

const ratingLevels = ['MUITO_BOM', 'BOM', 'FACIL', 'RUIM', 'MUITO_RUIM'];

String weekDayLabel(String weekDay) => weekDayLabels[weekDay] ?? weekDay;
String weekDayShortLabel(String weekDay) => weekDayShort[weekDay] ?? weekDay;
String ratingLabel(String rating) => ratingLabels[rating] ?? rating;

String formatDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '0:00';
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatElapsed(int? ms) {
  if (ms == null) return '—';
  if (ms < 1000) return '${ms}ms';
  final sec = (ms / 1000).round();
  if (sec < 60) return '${sec}s';
  return formatDuration(sec);
}

String resolveMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http')) return url;
  return '${AuthService.apiBase}$url';
}

class StudentStats {
  const StudentStats({
    required this.daysCompletedThisWeek,
    required this.totalWorkoutsCompleted,
    required this.currentStreak,
    this.completedWeekDays = const [],
  });

  final int daysCompletedThisWeek;
  final int totalWorkoutsCompleted;
  final int currentStreak;
  final List<String> completedWeekDays;

  factory StudentStats.fromJson(Map<String, dynamic> json) {
    return StudentStats(
      daysCompletedThisWeek: (json['daysCompletedThisWeek'] as num?)?.toInt() ?? 0,
      totalWorkoutsCompleted: (json['totalWorkoutsCompleted'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      completedWeekDays: (json['completedWeekDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    this.description,
    this.sets,
    this.reps,
    this.duration,
    this.videoUrl,
    this.mediaType = 'NONE',
    this.variationNotes,
    this.notes,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? description;
  final int? sets;
  final String? reps;
  final String? duration;
  final String? videoUrl;
  final String mediaType;
  final String? variationNotes;
  final String? notes;
  final int sortOrder;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Exercício',
      description: json['description'] as String?,
      sets: (json['sets'] as num?)?.toInt(),
      reps: json['reps']?.toString(),
      duration: json['duration']?.toString(),
      videoUrl: json['videoUrl'] as String?,
      mediaType: (json['mediaType'] as String? ?? 'NONE').toUpperCase(),
      variationNotes: json['variationNotes'] as String?,
      notes: json['notes'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  int get setCount => sets ?? 1;
}

class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.weekDay,
    this.muscleGroup,
    this.notes,
    this.restDay = false,
    this.sortOrder = 0,
    this.exercises = const [],
    this.activeSessionId,
    this.completedThisWeek = false,
  });

  final String id;
  final String weekDay;
  final String? muscleGroup;
  final String? notes;
  final bool restDay;
  final int sortOrder;
  final List<WorkoutExercise> exercises;
  final String? activeSessionId;
  final bool completedThisWeek;

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      id: json['id'] as String,
      weekDay: json['weekDay'] as String? ?? 'MONDAY',
      muscleGroup: json['muscleGroup'] as String?,
      notes: json['notes'] as String?,
      restDay: json['restDay'] as bool? ?? false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      activeSessionId: json['activeSessionId'] as String?,
      completedThisWeek: json['completedThisWeek'] as bool? ?? false,
    );
  }
}

class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.title,
    this.description,
    this.active = true,
    this.days = const [],
  });

  final String id;
  final String title;
  final String? description;
  final bool active;
  final List<WorkoutDay> days;

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) {
    return WorkoutProgram(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Ficha semanal',
      description: json['description'] as String?,
      active: json['active'] as bool? ?? true,
      days: (json['days'] as List<dynamic>?)
              ?.map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Dias ordenados segunda→domingo, só os que existem na ficha.
  List<WorkoutDay> get orderedDays {
    final byWeek = {for (final d in days) d.weekDay: d};
    return [
      for (final wd in weekDayOrder)
        if (byWeek.containsKey(wd)) byWeek[wd]!,
    ];
  }
}

class SetLog {
  const SetLog({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    this.completedAt,
    this.elapsedMs,
  });

  final String id;
  final String exerciseId;
  final int setNumber;
  final String? completedAt;
  final int? elapsedMs;

  factory SetLog.fromJson(Map<String, dynamic> json) {
    return SetLog(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      setNumber: (json['setNumber'] as num).toInt(),
      completedAt: json['completedAt'] as String?,
      elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.workoutDayId,
    required this.startedAt,
    this.completedAt,
    this.totalDurationSeconds,
    this.rating,
    this.comment,
    this.setLogs = const [],
  });

  final String id;
  final String workoutDayId;
  final String startedAt;
  final String? completedAt;
  final int? totalDurationSeconds;
  final String? rating;
  final String? comment;
  final List<SetLog> setLogs;

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      workoutDayId: json['workoutDayId'] as String,
      startedAt: json['startedAt'] as String,
      completedAt: json['completedAt'] as String?,
      totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt(),
      rating: json['rating'] as String?,
      comment: json['comment'] as String?,
      setLogs: (json['setLogs'] as List<dynamic>?)
              ?.map((e) => SetLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  bool get isCompleted => completedAt != null;

  Map<String, Set<int>> get completedSetsByExercise {
    final map = <String, Set<int>>{};
    for (final log in setLogs) {
      map.putIfAbsent(log.exerciseId, () => <int>{}).add(log.setNumber);
    }
    return map;
  }
}

class SessionComplete {
  const SessionComplete({
    required this.session,
    required this.stats,
    required this.message,
  });

  final WorkoutSession session;
  final StudentStats stats;
  final String message;

  factory SessionComplete.fromJson(Map<String, dynamic> json) {
    return SessionComplete(
      session: WorkoutSession.fromJson(json['session'] as Map<String, dynamic>),
      stats: StudentStats.fromJson(json['stats'] as Map<String, dynamic>),
      message: json['message'] as String? ?? 'Treino concluído!',
    );
  }
}

class WorkoutService {
  WorkoutService._();
  static final instance = WorkoutService._();

  Future<WorkoutProgram?> getActiveProgram() async {
    try {
      final data = await AuthService.instance.get('/api/student/programs/active');
      return WorkoutProgram.fromJson(data);
    } on SessionExpiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<StudentStats> getStats() async {
    final data = await AuthService.instance.get('/api/student/stats');
    return StudentStats.fromJson(data);
  }

  Future<WorkoutDay> getDay(String dayId) async {
    final data = await AuthService.instance.get('/api/student/days/$dayId');
    return WorkoutDay.fromJson(data);
  }

  Future<WorkoutSession> startOrResumeSession(String dayId) async {
    final data = await AuthService.instance.post('/api/student/days/$dayId/sessions', {});
    return WorkoutSession.fromJson(data);
  }

  Future<WorkoutSession> toggleSet({
    required String sessionId,
    required String exerciseId,
    required int setNumber,
  }) async {
    final data = await AuthService.instance.post('/api/student/sessions/$sessionId/sets', {
      'exerciseId': exerciseId,
      'setNumber': setNumber,
    });
    return WorkoutSession.fromJson(data);
  }

  Future<SessionComplete> completeSession({
    required String sessionId,
    required String rating,
    String? comment,
  }) async {
    final data = await AuthService.instance.post('/api/student/sessions/$sessionId/complete', {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return SessionComplete.fromJson(data);
  }
}
