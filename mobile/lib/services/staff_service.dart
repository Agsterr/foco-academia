import 'auth_service.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
int _int(Object? v) => v is num ? v.toInt() : 0;

/// O que a equipe vê: painel da academia (gestor ou personal autônomo) ou só os próprios alunos.
class StaffAccess {
  const StaffAccess({required this.manager, required this.personal, this.academyName, this.academySlug});

  final bool manager;
  final bool personal;
  final String? academyName;
  final String? academySlug;

  factory StaffAccess.fromJson(Map<String, dynamic> j) => StaffAccess(
        manager: j['manager'] == true,
        personal: j['personal'] == true,
        academyName: j['academyName'] as String?,
        academySlug: j['academySlug'] as String?,
      );
}

class MonthPoint {
  const MonthPoint({required this.month, required this.sessions, required this.activeStudents});

  /// "2026-11".
  final String month;
  final int sessions;
  final int activeStudents;

  /// "nov", "dez"...
  String get shortLabel {
    const names = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final m = int.tryParse(month.split('-').last) ?? 1;
    return names[(m - 1).clamp(0, 11)];
  }

  factory MonthPoint.fromJson(Map<String, dynamic> j) => MonthPoint(
        month: j['month'] as String? ?? '',
        sessions: _int(j['sessions']),
        activeStudents: _int(j['activeStudents']),
      );
}

class InstructorStats {
  const InstructorStats({
    required this.id,
    required this.name,
    required this.email,
    required this.active,
    required this.students,
    required this.sessions30d,
    required this.averageRating,
    required this.pendingSuggestions,
  });

  final String id;
  final String name;
  final String email;
  final bool active;
  final int students;
  final int sessions30d;
  final double? averageRating;
  final int pendingSuggestions;

  factory InstructorStats.fromJson(Map<String, dynamic> j) => InstructorStats(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        active: j['active'] != false,
        students: _int(j['students']),
        sessions30d: _int(j['sessions30d']),
        averageRating: _double(j['averageRating']),
        pendingSuggestions: _int(j['pendingSuggestions']),
      );
}

class StaffStudent {
  const StaffStudent({
    required this.id,
    required this.name,
    required this.email,
    required this.active,
    this.instructorId,
    this.instructorName,
    this.lastActivityAt,
    required this.sessions30d,
    this.averageRating,
  });

  final String id;
  final String name;
  final String email;
  final bool active;
  final String? instructorId;
  final String? instructorName;
  final DateTime? lastActivityAt;
  final int sessions30d;
  final double? averageRating;

  /// Sem treinar há mais de 14 dias (ou nunca treinou): precisa de atenção.
  bool inactiveFor(DateTime now) =>
      lastActivityAt == null || now.difference(lastActivityAt!).inDays > 14;

  factory StaffStudent.fromJson(Map<String, dynamic> j) => StaffStudent(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        active: j['active'] != false,
        instructorId: j['instructorId'] as String?,
        instructorName: j['instructorName'] as String?,
        lastActivityAt: _date(j['lastActivityAt']),
        sessions30d: _int(j['sessions30d']),
        averageRating: _double(j['averageRating']),
      );
}

class ManagerDashboard {
  const ManagerDashboard({
    required this.academyName,
    required this.academySlug,
    required this.personal,
    required this.planMonthlyPrice,
    required this.planIncludedStudents,
    required this.instructors,
    required this.students,
    required this.activeStudents7d,
    required this.sessions30d,
    required this.averageRating30d,
    required this.pendingSuggestions,
    required this.ratingDistribution,
    required this.months,
    required this.instructorRanking,
  });

  final String academyName;
  final String academySlug;
  final bool personal;
  final double? planMonthlyPrice;
  final int planIncludedStudents;
  final int instructors;
  final int students;
  final int activeStudents7d;
  final int sessions30d;
  final double? averageRating30d;
  final int pendingSuggestions;
  final Map<String, int> ratingDistribution;
  final List<MonthPoint> months;
  final List<InstructorStats> instructorRanking;

  bool get overPlanLimit => planIncludedStudents > 0 && students > planIncludedStudents;

  factory ManagerDashboard.fromJson(Map<String, dynamic> j) => ManagerDashboard(
        academyName: j['academyName'] as String? ?? '',
        academySlug: j['academySlug'] as String? ?? '',
        personal: j['personal'] == true,
        planMonthlyPrice: _double(j['planMonthlyPrice']),
        planIncludedStudents: _int(j['planIncludedStudents']),
        instructors: _int(j['instructors']),
        students: _int(j['students']),
        activeStudents7d: _int(j['activeStudents7d']),
        sessions30d: _int(j['sessions30d']),
        averageRating30d: _double(j['averageRating30d']),
        pendingSuggestions: _int(j['pendingSuggestions']),
        ratingDistribution: {
          for (final e in ((j['ratingDistribution'] as Map?) ?? const {}).entries) '${e.key}': _int(e.value),
        },
        months: [
          for (final m in (j['months'] as List?) ?? const []) MonthPoint.fromJson(m as Map<String, dynamic>),
        ],
        instructorRanking: [
          for (final i in (j['instructorRanking'] as List?) ?? const [])
            InstructorStats.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// Nota que o aluno deu ao terminar um treino.
class RatingEntry {
  const RatingEntry({
    required this.studentName,
    this.instructorName,
    required this.rating,
    required this.score,
    this.comment,
    this.workout,
    this.at,
  });

  final String studentName;
  final String? instructorName;
  final String rating;

  /// 1 (muito ruim) a 5 (muito bom).
  final int score;
  final String? comment;
  final String? workout;
  final DateTime? at;

  static const _scores = {'MUITO_BOM': 5, 'BOM': 4, 'FACIL': 3, 'RUIM': 2, 'MUITO_RUIM': 1};

  factory RatingEntry.fromJson(Map<String, dynamic> j) => RatingEntry(
        studentName: j['studentName'] as String? ?? '',
        instructorName: j['instructorName'] as String?,
        rating: j['rating'] as String? ?? '',
        score: _int(j['score']),
        comment: j['comment'] as String?,
        workout: j['workout'] as String?,
        at: _date(j['at']),
      );

  /// Avaliação de treino vista pelo instrutor (`/api/instructor/session-feedbacks`).
  factory RatingEntry.fromSessionFeedback(Map<String, dynamic> j) {
    final rating = j['rating'] as String? ?? '';
    final student = j['student'] as Map<String, dynamic>?;
    final group = j['muscleGroup'] as String?;
    final title = j['programTitle'] as String?;
    return RatingEntry(
      studentName: student?['name'] as String? ?? '',
      rating: rating,
      score: _scores[rating] ?? 0,
      comment: j['comment'] as String?,
      workout: [title, group].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
      at: _date(j['completedAt']),
    );
  }
}

/// Sugestão ou reclamação de aluno.
class SuggestionEntry {
  const SuggestionEntry({
    required this.id,
    required this.studentName,
    this.instructorName,
    this.category,
    required this.message,
    required this.status,
    this.response,
    this.createdAt,
  });

  final String id;
  final String studentName;
  final String? instructorName;
  final String? category;
  final String message;
  final String status;
  final String? response;
  final DateTime? createdAt;

  bool get pending => status != 'RESPONDIDA' && (response == null || response!.isEmpty);

  factory SuggestionEntry.fromJson(Map<String, dynamic> j) => SuggestionEntry(
        id: j['id'] as String,
        studentName: j['studentName'] as String? ??
            ((j['student'] as Map<String, dynamic>?)?['name'] as String? ?? ''),
        instructorName: j['instructorName'] as String?,
        category: j['category'] as String?,
        message: j['message'] as String? ?? '',
        status: '${j['status'] ?? ''}',
        response: j['response'] as String?,
        createdAt: _date(j['createdAt']),
      );
}

/// Chamadas do painel da academia e do instrutor.
class StaffService {
  StaffService._();
  static final instance = StaffService._();

  AuthService get _api => AuthService.instance;

  Future<StaffAccess> access() async => StaffAccess.fromJson(await _api.get('/api/manager/access'));

  Future<ManagerDashboard> dashboard() async => ManagerDashboard.fromJson(await _api.get('/api/manager/dashboard'));

  Future<List<InstructorStats>> instructors() async => [
        for (final e in await _api.getList('/api/manager/instructors')) InstructorStats.fromJson(e as Map<String, dynamic>),
      ];

  /// [manager]: todos os alunos da academia; senão, só os do instrutor logado.
  Future<List<StaffStudent>> students({required bool manager}) async => [
        for (final e in await _api.getList(manager ? '/api/manager/students' : '/api/instructor/students/overview'))
          StaffStudent.fromJson(e as Map<String, dynamic>),
      ];

  Future<List<RatingEntry>> ratings({required bool manager}) async {
    if (manager) {
      return [for (final e in await _api.getList('/api/manager/ratings')) RatingEntry.fromJson(e as Map<String, dynamic>)];
    }
    return [
      for (final e in await _api.getList('/api/instructor/session-feedbacks'))
        if ((e as Map<String, dynamic>)['rating'] != null) RatingEntry.fromSessionFeedback(e),
    ];
  }

  Future<List<SuggestionEntry>> suggestions({required bool manager}) async => [
        for (final e in await _api.getList(manager ? '/api/manager/suggestions' : '/api/instructor/suggestions'))
          SuggestionEntry.fromJson(e as Map<String, dynamic>),
      ];

  Future<void> respond(String suggestionId, String response, {required bool manager}) => _api.post(
        manager ? '/api/manager/suggestions/$suggestionId/respond' : '/api/instructor/suggestions/$suggestionId/respond',
        {'response': response},
      );

  Future<void> createInstructor({required String name, required String email, required String password}) =>
      _api.post('/api/manager/instructors', {'name': name, 'email': email, 'password': password});

  Future<void> createStudent({
    required String name,
    required String email,
    required String password,
    String? instructorId,
  }) =>
      _api.post('/api/manager/students', {
        'name': name,
        'email': email,
        'password': password,
        if (instructorId != null) 'instructorId': instructorId,
      });

  Future<void> assignInstructor(String studentId, String instructorId) =>
      _api.put('/api/manager/students/$studentId/instructor', {'instructorId': instructorId});

  Future<void> setActive(String userId, bool active) =>
      _api.post('/api/manager/members/$userId/active?value=$active', {});
}
