import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/screens/register_screen.dart';
import 'package:foco_academia_mobile/screens/staff/staff_home_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/staff_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  String? password;

  @override
  Future<void> deletePassword() async => password = null;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> writePassword(String value) async => password = value;
}

final _dashboard = {
  'academyName': 'Academia Força',
  'academySlug': 'academia-forca',
  'personal': false,
  'planMonthlyPrice': 149.0,
  'planIncludedStudents': 100,
  'instructors': 2,
  'students': 12,
  'activeStudents7d': 6,
  'sessions30d': 40,
  'averageRating30d': 4.25,
  'pendingSuggestions': 1,
  'ratingDistribution': {'MUITO_BOM': 3, 'BOM': 2, 'FACIL': 0, 'RUIM': 1, 'MUITO_RUIM': 0},
  'months': [
    for (final (i, m) in ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'].indexed)
      {'month': m, 'sessions': 10 + i * 5, 'activeStudents': 3 + i},
  ],
  'instructorRanking': [
    {
      'id': 'i1',
      'name': 'Ana Instrutora',
      'email': 'ana@x.com',
      'active': true,
      'students': 7,
      'sessions30d': 30,
      'averageRating': 4.5,
      'pendingSuggestions': 1,
    },
  ],
};

final _suggestion = {
  'id': 's1',
  'studentName': 'Bruno Aluno',
  'instructorName': 'Ana Instrutora',
  'category': 'Reclamação',
  'message': 'Ar-condicionado quebrado',
  'status': 'PENDENTE',
  'response': null,
  'createdAt': DateTime.now().toUtc().toIso8601String(),
};

/// API falsa: responde por caminho e guarda as chamadas.
MockClient _api(List<http.Request> calls, {Map<String, Object?> access = const {}}) {
  return MockClient((request) async {
    calls.add(request);
    final path = request.url.path;
    Object? body;
    if (path == '/api/manager/access') {
      body = {'manager': true, 'personal': false, 'academyName': 'Academia Força', 'academySlug': 'academia-forca', ...access};
    } else if (path == '/api/manager/dashboard') {
      body = {..._dashboard, 'personal': access['personal'] ?? false};
    } else if (path == '/api/manager/students' || path == '/api/instructor/students/overview') {
      body = [
        {
          'id': 'a1',
          'name': 'Bruno Aluno',
          'email': 'bruno@x.com',
          'active': true,
          'instructorId': 'i1',
          'instructorName': 'Ana Instrutora',
          'lastActivityAt': DateTime.now().toUtc().toIso8601String(),
          'sessions30d': 4,
          'averageRating': 4.0,
        },
      ];
    } else if (path.endsWith('/suggestions')) {
      body = [_suggestion];
    } else if (path.endsWith('/respond')) {
      body = {..._suggestion, 'status': 'RESPONDIDA'};
    } else if (path == '/api/manager/ratings' || path == '/api/instructor/session-feedbacks' || path == '/api/manager/instructors') {
      body = [];
    } else if (path == '/api/auth/refresh') {
      body = {'token': 'token'};
    } else if (path == '/api/auth/heartbeat') {
      return http.Response('', 204);
    } else {
      return http.Response('{"message":"não encontrado"}', 404);
    }
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Future<void> _pumpStaffHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2200);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const StaffHomeScreen()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 'token'
      ..role = null
      ..deviceId = 'device-1'
      ..credentialStore = _MemoryCredentialStore();
  });

  group('cadastro de academia e personal', () {
    test('academia vira gestor, entra sem código e lembra o perfil', () async {
      final calls = <http.Request>[];
      final client = MockClient((request) async {
        calls.add(request);
        return http.Response(
          jsonEncode({
            'token': 'novo-token',
            'academySlug': 'academia-forca',
            'user': {'id': 'u1', 'name': 'Dono', 'email': 'dono@x.com', 'role': 'GESTOR'},
          }),
          200,
        );
      });

      await http.runWithClient(() async {
        await AuthService.instance.registerBusiness(
          type: 'ACADEMIA',
          academyName: '  Academia Força ',
          name: 'Dono',
          email: 'dono@x.com',
          password: 'segredo123',
        );
      }, () => client);

      expect(calls.single.url.path, '/api/auth/register-business');
      final sent = jsonDecode(calls.single.body) as Map<String, dynamic>;
      expect(sent['type'], 'ACADEMIA');
      expect(sent['academyName'], 'Academia Força');
      expect(sent['deviceId'], 'device-1');
      expect(AuthService.instance.token, 'novo-token');
      expect(AuthService.instance.role, 'GESTOR');
      expect(AuthService.instance.isStaff, isTrue);
      // O dono entra depois sem código da academia.
      expect((await AuthService.instance.savedCredentials())!.slug, '');

      await AuthService.instance.load();
      expect(AuthService.instance.role, 'GESTOR');
      await AuthService.instance.logout();
      expect(AuthService.instance.isStaff, isFalse);
    });

    test('sessão antiga sem perfil descobre o papel pela API', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/me');
        return http.Response(jsonEncode({'id': 'u1', 'role': 'INSTRUTOR'}), 200);
      });
      await http.runWithClient(() => AuthService.instance.ensureRole(), () => client);
      expect(AuthService.instance.role, 'INSTRUTOR');
      expect(AuthService.instance.isStaff, isTrue);
    });

    testWidgets('perfil academia pede o nome da academia e chama o cadastro certo', (tester) async {
      final calls = <http.Request>[];
      final client = MockClient((request) async {
        calls.add(request);
        return http.Response('{"message":"E-mail já cadastrado"}', 400);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const RegisterScreen()));
        expect(find.byKey(const Key('register-academy')), findsNothing);

        await tester.tap(find.text('Academia'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('register-academy')), findsOneWidget);
        expect(find.text('Sua academia no controle'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('register-name')), 'Dono da Academia');
        await tester.enterText(find.byKey(const Key('register-email')), 'dono@x.com');
        await tester.enterText(find.byKey(const Key('register-password')), 'segredo123');
        await tester.enterText(find.byKey(const Key('register-confirm')), 'segredo123');
        await tester.ensureVisible(find.byKey(const Key('register-submit')));
        await tester.tap(find.byKey(const Key('register-submit')));
        await tester.pumpAndSettle();
        expect(find.text('Informe o nome da academia'), findsOneWidget);
        expect(calls, isEmpty);

        await tester.enterText(find.byKey(const Key('register-academy')), 'Academia Força');
        await tester.ensureVisible(find.byKey(const Key('register-submit')));
        await tester.tap(find.byKey(const Key('register-submit')));
        await tester.pumpAndSettle();
      }, () => client);

      expect(calls.single.url.path, '/api/auth/register-business');
      expect((jsonDecode(calls.single.body) as Map)['academyName'], 'Academia Força');
      expect(find.text('E-mail já cadastrado'), findsOneWidget);
    });
  });

  group('painel da equipe', () {
    testWidgets('gestor vê painel, alunos, instrutores e retorno', (tester) async {
      final calls = <http.Request>[];
      await http.runWithClient(() async {
        await _pumpStaffHome(tester);
      }, () => _api(calls));

      expect(find.text('Painel'), findsWidgets);
      expect(find.text('Instrutores'), findsOneWidget);
      expect(find.text('Retorno'), findsOneWidget);
      // Números e cálculos do painel.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('4,3'), findsOneWidget);
      expect(find.text('50% dos alunos treinaram nos últimos 7 dias'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('months-chart')), 300);
      expect(find.byKey(const Key('months-chart')), findsOneWidget);
      expect(find.text('nov'), findsOneWidget);
      expect(find.text('+17%'), findsOneWidget); // 30 → 35 treinos no último mês
    });

    testWidgets('instrutor autônomo não tem aba de instrutores', (tester) async {
      AuthService.instance.role = 'INSTRUTOR';
      await http.runWithClient(() async {
        await _pumpStaffHome(tester);
      }, () => _api([], access: {'personal': true, 'academyName': 'Fulano'}));

      expect(find.text('Painel'), findsWidgets);
      expect(find.text('Instrutores'), findsNothing);
      expect(find.text('Personal · Fulano'), findsOneWidget);
    });

    testWidgets('instrutor de academia vê só os próprios alunos e responde recados', (tester) async {
      AuthService.instance.role = 'INSTRUTOR';
      final calls = <http.Request>[];
      await http.runWithClient(() async {
        await _pumpStaffHome(tester);

        expect(find.text('Painel'), findsNothing);
        expect(find.text('Meus alunos'), findsWidgets);
        expect(find.text('Bruno Aluno'), findsOneWidget);

        await tester.tap(find.text('Retorno'));
        await tester.pumpAndSettle();
        expect(find.text('Ar-condicionado quebrado'), findsOneWidget);

        await tester.tap(find.text('Ar-condicionado quebrado'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('response-field')), 'Técnico chamado');
        await tester.tap(find.byKey(const Key('send-response')));
        await tester.pumpAndSettle();
      }, () => _api(calls, access: {'manager': false}));

      final paths = calls.map((c) => c.url.path).toList();
      expect(paths, contains('/api/instructor/students/overview'));
      expect(paths, isNot(contains('/api/manager/dashboard')));
      final respond = calls.singleWhere((c) => c.url.path == '/api/instructor/suggestions/s1/respond');
      expect(jsonDecode(respond.body), {'response': 'Técnico chamado'});
    });
  });

  group('modelos', () {
    test('avaliação do instrutor vira nota de 1 a 5', () {
      final r = RatingEntry.fromSessionFeedback({
        'student': {'name': 'Bruno'},
        'programTitle': 'Ficha A',
        'muscleGroup': 'Peito',
        'rating': 'RUIM',
        'comment': 'Pesado',
        'completedAt': '2026-11-01T10:00:00Z',
      });
      expect(r.score, 2);
      expect(r.studentName, 'Bruno');
      expect(r.workout, 'Ficha A · Peito');
    });

    test('aluno sem treinar há mais de 14 dias pede atenção', () {
      final now = DateTime(2026, 11, 20);
      StaffStudent student(DateTime? last) => StaffStudent(
            id: 'a',
            name: 'A',
            email: 'a@x',
            active: true,
            sessions30d: 0,
            lastActivityAt: last,
          );
      expect(student(null).inactiveFor(now), isTrue);
      expect(student(DateTime(2026, 11, 1)).inactiveFor(now), isTrue);
      expect(student(DateTime(2026, 11, 10)).inactiveFor(now), isFalse);
      expect(relativeDay(DateTime(2026, 11, 19), now: now), 'ontem');
      expect(relativeDay(null, now: now), 'nunca treinou');
    });
  });
}
