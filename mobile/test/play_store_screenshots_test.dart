// Capturas de tela para a Play Store, renderizadas com as telas reais do app e dados de demonstração.
//
// Só roda quando recebe a pasta das fontes do SDK (no CI fica pulado):
//   flutter test test/play_store_screenshots_test.dart \
//     --dart-define=FONT_DIR=<flutter>/bin/cache/artifacts/material_fonts \
//     --dart-define=SHOTS_DIR=<pasta de saída> --dart-define=PLAY_SCREENSHOTS=true
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/screens/calorie_stats_screen.dart';
import 'package:foco_academia_mobile/screens/cardio_history_screen.dart';
import 'package:foco_academia_mobile/screens/cardio_screen.dart';
import 'package:foco_academia_mobile/screens/home_screen.dart';
import 'package:foco_academia_mobile/screens/my_programs_screen.dart';
import 'package:foco_academia_mobile/screens/premium_screen.dart';
import 'package:foco_academia_mobile/screens/profile_screen.dart';
import 'package:foco_academia_mobile/screens/weight_screen.dart';
import 'package:foco_academia_mobile/screens/invite_screen.dart';
import 'package:foco_academia_mobile/screens/login_screen.dart';
import 'package:foco_academia_mobile/screens/register_screen.dart';
import 'package:foco_academia_mobile/screens/staff/staff_home_screen.dart';
import 'package:foco_academia_mobile/screens/templates_screen.dart';
import 'package:foco_academia_mobile/screens/workout_day_screen.dart';
import 'package:foco_academia_mobile/screens/workouts_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fontDir = String.fromEnvironment('FONT_DIR');
const _outDir = String.fromEnvironment('SHOTS_DIR', defaultValue: 'build/play_store');

/// 1080 × 1920 (9:16), dentro do que a Play Store aceita para celular.
/// O site usa telas mais altas (`--dart-define=SHOT_HEIGHT=2250`).
const _physical = Size(1080, int.fromEnvironment('SHOT_HEIGHT', defaultValue: 1920) * 1.0);
const _dpr = 2.625;

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async => ByteData.view((await File(path).readAsBytes()).buffer);
  final poppins = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    poppins.addFont(bytes('assets/fonts/Poppins-$w.ttf'));
  }
  await poppins.load();
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(bytes('$_fontDir/Roboto-$w.ttf'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(bytes('$_fontDir/MaterialIcons-Regular.otf'))).load();
}

String _iso(Duration fromNow) => DateTime.now().add(fromNow).toUtc().toIso8601String();

Map<String, dynamic> _exercise(String id, String name, int sets, int reps, [int order = 1]) =>
    {'id': id, 'name': name, 'sets': sets, 'reps': reps, 'sortOrder': order, 'mediaType': 'NONE'};

final _legDay = {
  'id': 'd3',
  'weekDay': 'WEDNESDAY',
  'muscleGroup': 'Pernas e glúteos',
  'restDay': false,
  'sortOrder': 3,
  'activeSessionId': 's1',
  'completedThisWeek': false,
  'notes': 'Foco na amplitude. Descanso de 90 s.',
  'exercises': [
    _exercise('e1', 'Agachamento livre', 4, 10, 1),
    _exercise('e2', 'Leg press 45°', 4, 12, 2),
    _exercise('e3', 'Cadeira extensora', 3, 15, 3),
    _exercise('e4', 'Stiff com halteres', 3, 12, 4),
    _exercise('e5', 'Elevação pélvica', 3, 12, 5),
  ],
};

Map<String, dynamic> _day(String id, String weekDay, String group, int order,
        {bool rest = false, bool done = false, int exercises = 6}) =>
    {
      'id': id,
      'weekDay': weekDay,
      'muscleGroup': rest ? 'Descanso' : group,
      'restDay': rest,
      'sortOrder': order,
      'completedThisWeek': done,
      'exercises': [for (var i = 0; i < (rest ? 0 : exercises); i++) _exercise('$id-$i', 'Exercício $i', 3, 12, i)],
    };

final _program = {
  'id': 'p1',
  'title': 'Hipertrofia · Fase 1',
  'description': 'Montada pela Ana · 5 dias por semana',
  'active': true,
  'instructorName': 'Ana Ribeiro',
  'days': [
    _day('d1', 'MONDAY', 'Peito e tríceps', 1, done: true),
    _day('d2', 'TUESDAY', 'Costas e bíceps', 2, done: true, exercises: 7),
    _legDay,
    _day('d4', 'THURSDAY', 'Ombros e abdômen', 4),
    _day('d5', 'FRIDAY', 'Full body + cardio', 5, exercises: 8),
    _day('d6', 'SATURDAY', '', 6, rest: true),
    _day('d7', 'SUNDAY', '', 7, rest: true),
  ],
};

const _templateText = {
  'MUSCULACAO': ['Musculação', 'Hipertrofia', 'Força total', 'Treino ABC para ganhar massa com segurança.'],
  'CORRIDA': ['Corrida', 'Primeiros 5 km', 'Ritmo e resistência', 'Intervalos de corrida e caminhada com aviso por voz.'],
  'SPINNING': ['Spinning', 'Pedal leve', 'Intervalado na bike', 'Subidas, sprints e recuperação no ritmo da música.'],
  'BIKE': ['Bike', 'Passeio ativo', 'Longão de fim de semana', 'Pedal outdoor com GPS, velocidade e calorias.'],
};

List<Map<String, dynamic>> get _templates => [
      for (final m in _templateText.entries)
        for (final (i, level) in ['INICIANTE', 'INTERMEDIARIO', 'AVANCADO'].indexed)
          {
            'key': '${m.key.toLowerCase()}-$i',
            'title': i == 0 ? '${m.value[1]} · iniciante' : (i == 1 ? m.value[2] : '${m.value[2]} avançado'),
            'modality': m.key,
            'level': level,
            'kind': m.key == 'MUSCULACAO' ? 'PROGRAM' : 'CARDIO',
            'description': m.value[3],
            'daysPerWeek': 3 + i,
            'sessionMinutes': 35 + i * 10,
          },
    ];

final _dashboard = {
  'academyName': 'Academia Força Total',
  'academySlug': 'forca-total',
  'personal': false,
  'planMonthlyPrice': 149.0,
  'planIncludedStudents': 100,
  'instructors': 4,
  'students': 86,
  'activeStudents7d': 61,
  'sessions30d': 742,
  'averageRating30d': 4.6,
  'pendingSuggestions': 3,
  'ratingDistribution': {'MUITO_BOM': 212, 'BOM': 96, 'FACIL': 31, 'RUIM': 9, 'MUITO_RUIM': 2},
  'months': [
    for (final (i, m) in ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10', '2026-11'].indexed)
      {'month': m, 'sessions': [410, 468, 520, 590, 655, 742][i], 'activeStudents': [38, 44, 51, 57, 66, 79][i]},
  ],
  'instructorRanking': [
    for (final (i, n) in ['Ana Ribeiro', 'Carlos Mendes', 'Juliana Prado', 'Rafael Lima'].indexed)
      {
        'id': 'i$i',
        'name': n,
        'email': 'x@x.com',
        'active': true,
        'students': [28, 24, 19, 15][i],
        'sessions30d': [261, 214, 163, 104][i],
        'averageRating': [4.8, 4.6, 4.5, 4.3][i],
        'pendingSuggestions': [0, 1, 2, 0][i],
      },
  ],
};

List<Map<String, dynamic>> get _students => [
      for (final (i, s) in [
        ('Bruno Almeida', 'Ana Ribeiro', 0, 14, 4.8),
        ('Camila Souza', 'Ana Ribeiro', 1, 12, 4.6),
        ('Diego Ferreira', 'Carlos Mendes', 0, 16, 5.0),
        ('Fernanda Lopes', 'Juliana Prado', 2, 9, 4.4),
        ('Gabriel Rocha', 'Carlos Mendes', 19, 1, 3.5),
        ('Helena Martins', 'Rafael Lima', 3, 8, 4.2),
        ('Igor Nascimento', 'Ana Ribeiro', 1, 11, 4.7),
        ('Júlia Castro', 'Juliana Prado', 0, 13, 4.9),
      ].indexed)
        {
          'id': 'a$i',
          'name': s.$1,
          'email': '${s.$1.split(' ').first.toLowerCase()}@email.com',
          'active': true,
          'instructorId': 'i0',
          'instructorName': s.$2,
          'lastActivityAt': _iso(Duration(days: -s.$3, hours: -2)),
          'sessions30d': s.$4,
          'averageRating': s.$5,
        },
    ];

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<http.Response> _demoApi(http.Request r) async {
  final path = r.url.path;
  switch (path) {
    case '/api/auth/heartbeat':
      return http.Response('', 204);
    case '/api/auth/refresh':
      return _json({'token': 't'});
    case '/api/student/calorie-stats':
      return _json({
        'caloriesToday': 486,
        'kmToday': 5.2,
        'minutesToday': 52,
        'totalKm': 312.4,
        'totalSessions': 64,
        'cardioSessions': 40,
        'totalHours': 58,
        'currentStreakDays': 6,
      });
    case '/api/student/subscription':
      return _json({'premium': true, 'reason': 'TRIAL', 'expiresAt': _iso(const Duration(days: 5)), 'enforced': true});
    case '/api/student/programs/active':
      return _json(_program);
    case '/api/student/stats':
      return _json({'daysCompletedThisWeek': 2, 'totalWorkoutsCompleted': 48, 'currentStreak': 6, 'completedWeekDays': ['MONDAY', 'TUESDAY']});
    case '/api/student/days/d3':
      return _json(_legDay);
    case '/api/student/days/d3/sessions':
      return _json({
        'id': 's1',
        'workoutDayId': 'd3',
        'startedAt': _iso(const Duration(minutes: -23, seconds: -41)),
        'setLogs': [
          for (var n = 1; n <= 4; n++) {'id': 'l$n', 'exerciseId': 'e1', 'setNumber': n, 'elapsedMs': n * 150000},
          for (var n = 1; n <= 2; n++) {'id': 'm$n', 'exerciseId': 'e2', 'setNumber': n, 'elapsedMs': 700000 + n * 140000},
        ],
      });
    case '/api/student/profile':
      return _json({'weightKg': 78, 'heightCm': 178, 'age': 29});
    case '/api/student/programs':
      return _json([
        {..._program, 'ownedByStudent': false},
        {
          'id': 'p2',
          'title': 'Meu treino de férias',
          'active': false,
          'ownedByStudent': true,
          'days': [_day('x1', 'MONDAY', 'Corpo todo', 1), _day('x2', 'THURSDAY', 'Corpo todo', 2)],
        },
      ]);
    case '/api/student/measurements':
      return _json([
        for (var i = 0; i < 10; i++)
          {'id': 'w$i', 'weightKg': 84.0 - i * 0.7 + (i.isEven ? 0.3 : 0), 'recordedAt': _iso(Duration(days: -(9 - i) * 7)), 'source': 'MANUAL'},
      ]);
    case '/api/student/cardio-sessions':
      return _json([
        for (var i = 0; i < 6; i++)
          {
            'id': 'c$i',
            'type': 'CORRIDA',
            'distanceMeters': 5200 + i * 300,
            'durationSec': 1800 + i * 60,
            'avgSpeedKmh': 10.4,
            'caloriesKcal': 380 + i * 10,
            'startedAt': _iso(Duration(days: -i * 2, hours: -3)),
            'completedAt': _iso(Duration(days: -i * 2, hours: -2)),
          },
      ]);
    case '/api/student/templates':
      return _json(_templates);
    case '/api/manager/access':
      return _json({'manager': true, 'personal': false, 'academyName': 'Academia Força Total', 'academySlug': 'forca-total'});
    case '/api/manager/dashboard':
      return _json(_dashboard);
    case '/api/manager/students':
      return _json(_students);
    case '/api/manager/instructors':
      return _json(_dashboard['instructorRanking']!);
    case '/api/manager/invites':
      if (r.method == 'POST') {
        return _json({
          'id': 'v1',
          'code': 'K7Q2MX9P3T',
          'url': 'https://academia.focodev.com.br/convite/K7Q2MX9P3T',
          'role': 'ALUNO',
          'name': 'Marina',
          'instructorName': 'Ana Ribeiro',
          'expiresAt': _iso(const Duration(days: 7)),
          'shareText': 'Oi, Marina!',
        });
      }
      return _json([]);
    case '/api/auth/invites/K7Q2MX9P3T':
      return _json({
        'code': 'K7Q2MX9P3T',
        'role': 'ALUNO',
        'academyName': 'Academia Força Total',
        'instructorName': 'Ana Ribeiro',
        'invitedBy': 'Ana Ribeiro',
        'name': 'Marina Costa',
        'personal': false,
      });
  }
  if (path.endsWith('/suggestions') || path.endsWith('/ratings') || path.endsWith('session-feedbacks')) {
    return _json([]);
  }
  return _json({'message': 'demo'}, 404);
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  tester.view.physicalSize = _physical;
  tester.view.devicePixelRatio = _dpr;
  final boundary = GlobalKey();
  await http.runWithClient(() async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.dark(), home: screen),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (interact != null) await interact(tester);
  }, () => MockClient(_demoApi));

  final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: _dpr);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  });
  // Troca de tela entre capturas sem herdar estado.
  await tester.pumpWidget(const SizedBox());
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final skip = _fontDir.isEmpty;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 't'
      ..deviceId = 'demo'
      ..userName = 'Bruno Almeida'
      ..role = 'ALUNO';
  });

  testWidgets('capturas da Play Store', (tester) async {
    await tester.runAsync(_loadFonts);
    addTearDown(tester.view.reset);

    await _shot(tester, '01_inicio', const HomeScreen());
    await _shot(tester, '02_ficha', const WorkoutsScreen());
    await _shot(tester, '03_treino', const WorkoutDayScreen(dayId: 'd3'));
    await _shot(tester, '04_treinos_prontos', const TemplatesScreen());

    AuthService.instance.role = 'GESTOR';
    await _shot(tester, '05_painel_academia', const StaffHomeScreen());
    await _shot(tester, '06_alunos', const StaffHomeScreen(), interact: (t) async {
      await t.tap(find.text('Alunos').last);
      await _settle(t);
    });
    AuthService.instance.role = 'INSTRUTOR';
    await _shot(tester, '07_convite', const StaffHomeScreen(), interact: (t) async {
      await t.tap(find.text('Alunos').last);
      await _settle(t);
      await t.tap(find.byKey(const Key('new-student')));
      await _settle(t);
      await t.tap(find.byKey(const Key('add-by-invite')));
      await _settle(t);
      await t.enterText(find.byKey(const Key('invite-name-field')), 'Marina');
      await t.tap(find.byKey(const Key('create-invite')));
      await _settle(t);
    });
    AuthService.instance.role = 'ALUNO';
    await _shot(tester, '08_aceitar_convite', const InviteScreen(code: 'K7Q2MX9P3T'));

    AuthService.instance.token = null;
    await _shot(tester, '09_login', const LoginScreen());
    await _shot(tester, '10_cadastro', const RegisterScreen(initialProfile: SignupProfile.academia));
  }, skip: skip);

  // Outras telas, para conferir o tema (não vão para a loja).
  for (final (name, screen) in [
    ('extra_premium', const PremiumScreen()),
    ('extra_meus_treinos', const MyProgramsScreen()),
    ('extra_perfil', const ProfileScreen()),
    ('extra_estatisticas', const CalorieStatsScreen()),
    ('extra_evolucao', const WeightScreen()),
    ('extra_historico', const CardioHistoryScreen()),
    ('extra_outdoor', const CardioScreen()),
  ]) {
    testWidgets(name, (tester) async {
      await tester.runAsync(_loadFonts);
      addTearDown(tester.view.reset);
      await _shot(tester, name, screen);
    }, skip: skip);
  }
}
