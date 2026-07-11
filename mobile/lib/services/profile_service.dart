import '../services/auth_service.dart';

class StudentProfile {
  const StudentProfile({
    required this.studentId,
    required this.studentName,
    this.heightCm,
    this.currentWeightKg,
    this.goal,
    this.onboardingCompleted = false,
    this.sex,
    this.birthDate,
    this.age,
    this.activityLevel,
  });

  final String studentId;
  final String studentName;
  final double? heightCm;
  final double? currentWeightKg;
  final String? goal;
  final bool onboardingCompleted;
  final String? sex;
  final String? birthDate;
  final int? age;
  final String? activityLevel;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String? ?? '',
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      currentWeightKg: (json['currentWeightKg'] as num?)?.toDouble(),
      goal: json['goal'] as String?,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      sex: json['sex'] as String?,
      birthDate: json['birthDate'] as String?,
      age: (json['age'] as num?)?.toInt(),
      activityLevel: json['activityLevel'] as String?,
    );
  }
}

class CaloriePeriodBucket {
  const CaloriePeriodBucket({
    required this.label,
    required this.calories,
    this.km = 0,
    required this.sessions,
  });

  final String label;
  final int calories;
  final double km;
  final int sessions;

  factory CaloriePeriodBucket.fromJson(Map<String, dynamic> json) {
    return CaloriePeriodBucket(
      label: json['label'] as String? ?? '',
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      km: (json['km'] as num?)?.toDouble() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

class DistanceSession {
  const DistanceSession({
    required this.id,
    required this.completedAt,
    required this.title,
    required this.distanceKm,
    this.caloriesKcal,
    this.elapsedMs,
    this.avgSpeedKmh,
  });

  final String id;
  final String completedAt;
  final String title;
  final double distanceKm;
  final int? caloriesKcal;
  final int? elapsedMs;
  final double? avgSpeedKmh;

  factory DistanceSession.fromJson(Map<String, dynamic> json) {
    return DistanceSession(
      id: json['id'] as String? ?? '',
      completedAt: json['completedAt'] as String? ?? '',
      title: json['title'] as String? ?? 'Outdoor',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      caloriesKcal: (json['caloriesKcal'] as num?)?.toInt(),
      elapsedMs: (json['elapsedMs'] as num?)?.toInt(),
      avgSpeedKmh: (json['avgSpeedKmh'] as num?)?.toDouble(),
    );
  }

  String get dateLabel {
    final dt = DateTime.tryParse(completedAt)?.toLocal();
    if (dt == null) return completedAt;
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m ${h}h$min';
  }
}

class CalorieStats {
  const CalorieStats({
    required this.caloriesToday,
    this.kmToday = 0,
    this.minutesToday = 0,
    required this.caloriesLast7Days,
    this.kmLast7Days = 0,
    required this.caloriesLast30Days,
    this.kmLast30Days = 0,
    required this.caloriesLast12Months,
    this.kmLast12Months = 0,
    required this.totalKm,
    required this.totalHours,
    required this.totalSessions,
    this.cardioSessions = 0,
    required this.avgCaloriesPerSession,
    required this.maxCaloriesSingleSession,
    required this.maxDistanceKm,
    required this.maxDurationMinutes,
    required this.currentStreakDays,
    this.weekly = const [],
    this.monthly = const [],
    this.yearly = const [],
    this.recentDistances = const [],
    this.estimateDisclaimer = '',
  });

  final int caloriesToday;
  final double kmToday;
  final int minutesToday;
  final int caloriesLast7Days;
  final double kmLast7Days;
  final int caloriesLast30Days;
  final double kmLast30Days;
  final int caloriesLast12Months;
  final double kmLast12Months;
  final double totalKm;
  final double totalHours;
  final int totalSessions;
  final int cardioSessions;
  final double avgCaloriesPerSession;
  final int maxCaloriesSingleSession;
  final double maxDistanceKm;
  final int maxDurationMinutes;
  final int currentStreakDays;
  final List<CaloriePeriodBucket> weekly;
  final List<CaloriePeriodBucket> monthly;
  final List<CaloriePeriodBucket> yearly;
  final List<DistanceSession> recentDistances;
  final String estimateDisclaimer;

  factory CalorieStats.fromJson(Map<String, dynamic> json) {
    List<CaloriePeriodBucket> buckets(String key) =>
        (json[key] as List<dynamic>?)
            ?.map((e) => CaloriePeriodBucket.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];

    return CalorieStats(
      caloriesToday: (json['caloriesToday'] as num?)?.toInt() ?? 0,
      kmToday: (json['kmToday'] as num?)?.toDouble() ?? 0,
      minutesToday: (json['minutesToday'] as num?)?.toInt() ?? 0,
      caloriesLast7Days: (json['caloriesLast7Days'] as num?)?.toInt() ?? 0,
      kmLast7Days: (json['kmLast7Days'] as num?)?.toDouble() ?? 0,
      caloriesLast30Days: (json['caloriesLast30Days'] as num?)?.toInt() ?? 0,
      kmLast30Days: (json['kmLast30Days'] as num?)?.toDouble() ?? 0,
      caloriesLast12Months: (json['caloriesLast12Months'] as num?)?.toInt() ?? 0,
      kmLast12Months: (json['kmLast12Months'] as num?)?.toDouble() ?? 0,
      totalKm: (json['totalKm'] as num?)?.toDouble() ?? 0,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      cardioSessions: (json['cardioSessions'] as num?)?.toInt() ?? 0,
      avgCaloriesPerSession: (json['avgCaloriesPerSession'] as num?)?.toDouble() ?? 0,
      maxCaloriesSingleSession: (json['maxCaloriesSingleSession'] as num?)?.toInt() ?? 0,
      maxDistanceKm: (json['maxDistanceKm'] as num?)?.toDouble() ?? 0,
      maxDurationMinutes: (json['maxDurationMinutes'] as num?)?.toInt() ?? 0,
      currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
      weekly: buckets('weekly'),
      monthly: buckets('monthly'),
      yearly: buckets('yearly'),
      recentDistances: (json['recentDistances'] as List<dynamic>?)
              ?.map((e) => DistanceSession.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      estimateDisclaimer: json['estimateDisclaimer'] as String? ?? '',
    );
  }
}

class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  Future<StudentProfile> getProfile() async {
    final data = await AuthService.instance.get('/api/student/profile');
    return StudentProfile.fromJson(data);
  }

  Future<StudentProfile> updateProfile({
    double? heightCm,
    double? weightKg,
    String? goal,
    String? sex,
    String? birthDate,
    String? activityLevel,
  }) async {
    final data = await AuthService.instance.put('/api/student/profile', {
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
      if (goal != null) 'goal': goal,
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birthDate': birthDate,
      if (activityLevel != null) 'activityLevel': activityLevel,
    });
    return StudentProfile.fromJson(data);
  }

  Future<CalorieStats> getCalorieStats() async {
    final data = await AuthService.instance.get('/api/student/calorie-stats');
    return CalorieStats.fromJson(data);
  }
}
