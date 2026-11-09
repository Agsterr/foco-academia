import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/data/exercise_library.dart';
import 'package:foco_academia_mobile/screens/register_screen.dart';
import 'package:foco_academia_mobile/screens/templates_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/workout_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.token = 'token';
  });

  group('montagem de ficha própria', () {
    test('dia sem exercícios vira descanso e repetições em texto vão para duração', () {
      final days = [
        DayDraft(weekDay: 'MONDAY', title: 'Peito', exercises: [
          ExerciseDraft(name: 'Supino reto', sets: 4, reps: '10'),
          ExerciseDraft(name: 'Prancha', sets: 3, reps: '30 s'),
        ]),
        DayDraft(weekDay: 'TUESDAY'),
      ];

      final body = WorkoutService.programBody('  Meu treino  ', days);

      expect(body['title'], 'Meu treino');
      final monday = (body['days'] as List)[0] as Map<String, dynamic>;
      final tuesday = (body['days'] as List)[1] as Map<String, dynamic>;
      expect(monday['restDay'], isFalse);
      expect(monday['muscleGroup'], 'Peito');
      final exercises = monday['exercises'] as List;
      expect(exercises[0], containsPair('reps', 10));
      expect((exercises[0] as Map).containsKey('duration'), isFalse);
      expect(exercises[1], containsPair('duration', '30 s'));
      expect((exercises[1] as Map).containsKey('reps'), isFalse);
      expect(tuesday['restDay'], isTrue);
      expect(tuesday['exercises'], isEmpty);
    });

    test('biblioteca de exercícios veio inteira do painel do instrutor', () {
      expect(exerciseLibrary.length, greaterThanOrEqualTo(70));
      expect(exerciseLibrary.every((e) => muscleLabels.containsKey(e.muscle)), isTrue);
    });
  });

  group('treinos prontos', () {
    final templates = [
      for (final m in ['MUSCULACAO', 'CORRIDA', 'SPINNING', 'BIKE'])
        for (final l in ['INICIANTE', 'INTERMEDIARIO', 'AVANCADO'])
          {
            'key': '${m.toLowerCase()}-${l.toLowerCase()}',
            'title': 'Treino $m $l',
            'modality': m,
            'level': l,
            'kind': m == 'CORRIDA' ? 'CARDIO' : 'PROGRAM',
            'description': 'Descrição',
            'daysPerWeek': 3,
            'sessionMinutes': 40,
          },
    ];

    testWidgets('filtra por modalidade e nível', (tester) async {
      final client = MockClient((request) async => http.Response(jsonEncode(templates), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const TemplatesScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Treino MUSCULACAO INICIANTE'), findsOneWidget);
        expect(find.text('Treino SPINNING INICIANTE'), findsNothing);

        await tester.tap(find.byKey(const Key('modality-SPINNING')));
        await tester.pumpAndSettle();
        expect(find.text('Treino SPINNING INICIANTE'), findsOneWidget);
        expect(find.text('Treino MUSCULACAO INICIANTE'), findsNothing);

        await tester.tap(find.text('Avançado'));
        await tester.pumpAndSettle();
        expect(find.text('Treino SPINNING AVANCADO'), findsOneWidget);
        expect(find.text('Treino SPINNING INICIANTE'), findsNothing);
      }, () => client);
    });
  });

  group('cadastro', () {
    testWidgets('valida nome, e-mail, senha e confirmação antes de chamar a API', (tester) async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response('{}', 500);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const RegisterScreen()));
        await tester.enterText(find.byKey(const Key('register-name')), 'A');
        await tester.enterText(find.byKey(const Key('register-email')), 'sem-arroba');
        await tester.enterText(find.byKey(const Key('register-password')), '123');
        await tester.enterText(find.byKey(const Key('register-confirm')), '321');
        await tester.ensureVisible(find.byKey(const Key('register-submit')));
        await tester.tap(find.byKey(const Key('register-submit')));
        await tester.pumpAndSettle();

        expect(find.text('Informe seu nome'), findsOneWidget);
        expect(find.text('Informe um e-mail válido'), findsOneWidget);
        expect(find.text('Use pelo menos 6 caracteres'), findsOneWidget);
        expect(find.text('As senhas não conferem'), findsOneWidget);
        expect(calls, 0);
      }, () => client);
    });
  });
}
