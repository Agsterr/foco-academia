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
    this.caloriesToday = 0,
    this.caloriesThisWeek = 0,
  });

  final int daysCompletedThisWeek;
  final int totalWorkoutsCompleted;
  final int currentStreak;
  final List<String> completedWeekDays;
  final int caloriesToday;
  final int caloriesThisWeek;

  factory StudentStats.fromJson(Map<String, dynamic> json) {
    return StudentStats(
      daysCompletedThisWeek: (json['daysCompletedThisWeek'] as num?)?.toInt() ?? 0,
      totalWorkoutsCompleted: (json['totalWorkoutsCompleted'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      completedWeekDays: (json['completedWeekDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      caloriesToday: (json['caloriesToday'] as num?)?.toInt() ?? 0,
      caloriesThisWeek: (json['caloriesThisWeek'] as num?)?.toInt() ?? 0,
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
    this.ownedByStudent = false,
    this.instructorName,
    this.templateKey,
  });

  final String id;
  final String title;
  final String? description;
  final bool active;
  final List<WorkoutDay> days;

  /// Ficha montada pelo próprio aluno (ou iniciada de um treino pronto).
  final bool ownedByStudent;
  final String? instructorName;
  final String? templateKey;

  /// Rótulo de origem mostrado na lista "Meus treinos".
  String get originLabel {
    if (!ownedByStudent) {
      return instructorName == null ? 'Da academia' : 'Da academia · $instructorName';
    }
    return templateKey == null ? 'Criado por você' : 'Treino pronto';
  }

  int get trainingDays => days.where((d) => !d.restDay).length;

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
      ownedByStudent: json['ownedByStudent'] as bool? ?? false,
      instructorName: json['instructorName'] as String?,
      templateKey: json['templateKey'] as String?,
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
    this.caloriesKcal,
    this.intensity,
    this.rating,
    this.comment,
    this.setLogs = const [],
  });

  final String id;
  final String workoutDayId;
  final String startedAt;
  final String? completedAt;
  final int? totalDurationSeconds;
  final int? caloriesKcal;
  final String? intensity;
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
      caloriesKcal: (json['caloriesKcal'] as num?)?.toInt(),
      intensity: json['intensity'] as String?,
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

/// Treino pronto do catálogo (musculação, corrida, spinning ou bike, por nível).
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.key,
    required this.title,
    required this.modality,
    required this.level,
    required this.kind,
    required this.description,
    required this.daysPerWeek,
    required this.sessionMinutes,
  });

  final String key;
  final String title;
  final String modality;
  final String level;

  /// PROGRAM (vira ficha semanal) ou CARDIO (vira treino outdoor de corrida).
  final String kind;
  final String description;
  final int daysPerWeek;
  final int sessionMinutes;

  bool get isCardio => kind == 'CARDIO';

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) => WorkoutTemplate(
        key: json['key'] as String,
        title: json['title'] as String? ?? '',
        modality: json['modality'] as String? ?? 'MUSCULACAO',
        level: json['level'] as String? ?? 'INICIANTE',
        kind: json['kind'] as String? ?? 'PROGRAM',
        description: json['description'] as String? ?? '',
        daysPerWeek: (json['daysPerWeek'] as num?)?.toInt() ?? 0,
        sessionMinutes: (json['sessionMinutes'] as num?)?.toInt() ?? 0,
      );
}

const templateModalities = {
  'MUSCULACAO': 'Musculação',
  'CORRIDA': 'Corrida',
  'SPINNING': 'Spinning',
  'BIKE': 'Bike',
};

const templateLevels = {
  'INICIANTE': 'Iniciante',
  'INTERMEDIARIO': 'Intermediário',
  'AVANCADO': 'Avançado',
};

/// Exercício na montagem de uma ficha própria.
class ExerciseDraft {
  ExerciseDraft({required this.name, this.sets = 3, this.reps = '12', this.duration, this.description});

  String name;
  int sets;
  String reps;
  String? duration;
  String? description;

  /// "12" vira repetições; texto como "30 s" ou "8-10" vai no campo de duração/observação.
  Map<String, dynamic> toJson(int order) {
    final repsNumber = int.tryParse(reps.trim());
    final freeText = repsNumber == null && reps.trim().isNotEmpty ? reps.trim() : null;
    final durationText = (duration != null && duration!.isNotEmpty) ? duration : freeText;
    return {
      'name': name,
      if (description != null && description!.isNotEmpty) 'description': description,
      'sets': sets,
      if (repsNumber != null) 'reps': repsNumber,
      if (durationText != null) 'duration': durationText,
      'sortOrder': order,
    };
  }
}

/// Dia na montagem de uma ficha própria.
class DayDraft {
  DayDraft({required this.weekDay, this.title = '', List<ExerciseDraft>? exercises})
      : exercises = exercises ?? [];

  final String weekDay;
  String title;
  final List<ExerciseDraft> exercises;

  bool get isRest => exercises.isEmpty;
}

class WorkoutService {
  WorkoutService._();
  static final instance = WorkoutService._();

  /// Todas as fichas que o aluno vê: as da academia e as próprias.
  Future<List<WorkoutProgram>> listPrograms() async {
    final data = await AuthService.instance.getList('/api/student/programs');
    return data.map((e) => WorkoutProgram.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Map<String, dynamic> programBody(String title, List<DayDraft> days) => {
        'title': title.trim(),
        'days': [
          for (final (i, d) in days.indexed)
            {
              'weekDay': d.weekDay,
              'muscleGroup': d.isRest ? 'Descanso' : (d.title.trim().isEmpty ? null : d.title.trim()),
              'restDay': d.isRest,
              'sortOrder': i + 1,
              'exercises': [
                for (final (j, e) in d.exercises.indexed) e.toJson(j + 1),
              ],
            },
        ],
      };

  Future<WorkoutProgram> createProgram(String title, List<DayDraft> days) async {
    final data = await AuthService.instance.post('/api/student/programs', programBody(title, days));
    return WorkoutProgram.fromJson(data);
  }

  /// Instrutor monta a ficha do aluno; ela passa a ser a ficha ativa dele.
  Future<void> createProgramForStudent(String studentId, String title, List<DayDraft> days) async {
    await AuthService.instance.post('/api/instructor/programs', {
      ...programBody(title, days),
      'studentId': studentId,
    });
  }

  Future<WorkoutProgram> updateProgram(String id, String title, List<DayDraft> days) async {
    final data = await AuthService.instance.put('/api/student/programs/$id', programBody(title, days));
    return WorkoutProgram.fromJson(data);
  }

  Future<void> deleteProgram(String id) => AuthService.instance.delete('/api/student/programs/$id');

  Future<void> activateProgram(String id) async {
    await AuthService.instance.post('/api/student/programs/$id/activate', {});
  }

  Future<List<WorkoutTemplate>> listTemplates() async {
    final data = await AuthService.instance.getList('/api/student/templates');
    return data.map((e) => WorkoutTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Começa um treino pronto: devolve "PROGRAM" ou "CARDIO".
  Future<String> startTemplate(String key) async {
    final data = await AuthService.instance.post('/api/student/templates/$key/start', {});
    return data['kind'] as String? ?? 'PROGRAM';
  }

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
    String intensity = 'MODERADA',
  }) async {
    final data = await AuthService.instance.post('/api/student/sessions/$sessionId/complete', {
      'rating': rating,
      'intensity': intensity,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return SessionComplete.fromJson(data);
  }
}
