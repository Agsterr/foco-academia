import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/data/home_workouts.dart';
import 'package:foco_academia_mobile/screens/home_workout_player_screen.dart';
import 'package:foco_academia_mobile/screens/home_workouts_screen.dart';
import 'package:foco_academia_mobile/services/home_workout_progress.dart';
import 'package:foco_academia_mobile/widgets/exercise_figure.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeWorkoutLog _log(DateTime at, {int kcal = 100, int exercises = 10, int xp = 100, String level = 'medio'}) =>
    HomeWorkoutLog(
      workoutId: 'x',
      title: 'x',
      level: level,
      at: at,
      seconds: 600,
      kcal: kcal,
      exercises: exercises,
      xp: xp,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('catálogo', () {
    test('todo passo aponta para um exercício existente e o último não tem descanso', () {
      for (final w in homeWorkouts) {
        expect(w.steps, isNotEmpty, reason: w.id);
        for (final s in w.steps) {
          expect(() => s.exercise, returnsNormally, reason: '${w.id}/${s.exerciseId}');
          expect(s.workSeconds, greaterThanOrEqualTo(15), reason: w.id);
        }
        expect(w.steps.last.restSeconds, 0, reason: w.id);
      }
    });

    test('há treinos em todas as intensidades e a intensidade aumenta as calorias', () {
      for (final l in HomeLevel.values) {
        expect(homeWorkouts.where((w) => w.level == l), isNotEmpty, reason: l.name);
      }
      final kcalPerMinute = {
        for (final l in HomeLevel.values)
          l: homeWorkouts.where((w) => w.level == l).map((w) => w.estimateKcal(70) / (w.totalSeconds / 60)).reduce((a, b) => a + b) /
              homeWorkouts.where((w) => w.level == l).length,
      };
      expect(kcalPerMinute[HomeLevel.leve]! < kcalPerMinute[HomeLevel.medio]!, isTrue);
      expect(kcalPerMinute[HomeLevel.medio]! < kcalPerMinute[HomeLevel.alto]!, isTrue);
      expect(kcalPerMinute[HomeLevel.alto]! < kcalPerMinute[HomeLevel.extremo]!, isTrue);
    });

    test('calorias: MET × peso × tempo', () {
      // 60 min de esforço leve (3,5 MET) com 70 kg = 245 kcal.
      expect(kcalFor(HomeLevel.leve, 3600, 0, 70), 245);
      expect(kcalFor(HomeLevel.leve, 0, 0, 70), 0);
    });

    test('ids de exercícios são únicos', () {
      final ids = homeExercises.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('desenhos', () {
    test('membros mantêm o comprimento e o boneco cabe no quadro em todas as poses', () {
      for (final e in homeExercises) {
        expect(e.figure.poses.length, greaterThanOrEqualTo(2), reason: e.id);
        for (var step = 0; step <= 20; step++) {
          final pose = e.figure.at(step / 20);
          final j = FigureJoints.fromPose(pose);
          expect((j.elbow - j.neck).distance, closeTo(FigureJoints.upperArm, 1e-9), reason: e.id);
          expect((j.hand - j.elbow).distance, closeTo(FigureJoints.foreArm, 1e-9), reason: e.id);
          expect((j.foot - j.knee).distance, closeTo(FigureJoints.shin, 1e-9), reason: e.id);
          for (final p in j.points) {
            expect(p.dx.isFinite && p.dy.isFinite, isTrue, reason: e.id);
          }
        }
        // Largura do ciclo todo (sem cortar nas bordas, já com a escala de 0,8 do desenho).
        var lo = double.infinity, hi = -double.infinity;
        for (final p in e.figure.poses) {
          final b = FigureJoints.fromPose(p).bounds;
          if (b.$1 < lo) lo = b.$1;
          if (b.$2 > hi) hi = b.$2;
        }
        expect((hi - lo) * 0.8, lessThan(0.9), reason: e.id);
      }
    });

    testWidgets('ExerciseFigure anima e para quando animate é falso', (tester) async {
      final e = homeExerciseById('burpee');
      await tester.pumpWidget(MaterialApp(home: ExerciseFigure(animation: e.figure, size: 120)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CustomPaint), findsWidgets);
      await tester.pumpWidget(MaterialApp(home: ExerciseFigure(animation: e.figure, size: 120, animate: false)));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('progresso', () {
    test('nível sobe com o XP (100, depois 150, 200...)', () {
      expect(PlayerLevel.fromXp(0).level, 1);
      expect(PlayerLevel.fromXp(99).level, 1);
      expect(PlayerLevel.fromXp(100).level, 2);
      expect(PlayerLevel.fromXp(100).xpInto, 0);
      expect(PlayerLevel.fromXp(249).level, 2);
      expect(PlayerLevel.fromXp(250).level, 3);
      expect(PlayerLevel.fromXp(100).xpNeeded, 150);
      expect(PlayerLevel.fromXp(1000000).title, PlayerLevel.titles.last);
    });

    test('sequência conta dias seguidos e perdoa o dia de hoje ainda vazio', () {
      final now = DateTime(2026, 11, 11, 20);
      final today = HomeWorkoutStats([
        _log(DateTime(2026, 11, 11, 7)),
        _log(DateTime(2026, 11, 10, 7)),
        _log(DateTime(2026, 11, 9, 7)),
        _log(DateTime(2026, 11, 5, 7)),
      ], now: now);
      expect(today.streak, 3);
      expect(today.bestStreak, 3);

      final yesterdayOnly = HomeWorkoutStats([_log(DateTime(2026, 11, 10, 7))], now: now);
      expect(yesterdayOnly.streak, 1);

      final broken = HomeWorkoutStats([_log(DateTime(2026, 11, 8, 7))], now: now);
      expect(broken.streak, 0);
      expect(broken.bestStreak, 1);
      expect(HomeWorkoutStats(const [], now: now).streak, 0);
    });

    test('calorias de hoje, últimos 7 dias e meta da semana (segunda a domingo)', () {
      final now = DateTime(2026, 11, 11, 20); // quarta-feira
      final stats = HomeWorkoutStats([
        _log(DateTime(2026, 11, 11, 7), kcal: 200),
        _log(DateTime(2026, 11, 11, 18), kcal: 50),
        _log(DateTime(2026, 11, 9, 7), kcal: 120), // segunda
        _log(DateTime(2026, 11, 8, 7), kcal: 80), // domingo anterior: fora da semana
      ], now: now);
      expect(stats.kcalToday, 250);
      expect(stats.workoutsThisWeek, 3);
      expect(stats.kcalLast7Days.last, 250);
      expect(stats.kcalLast7Days[4], 120);
      expect(stats.kcalLast7Days[3], 80);
      expect(stats.minutesToday, 20);
    });

    test('conquistas dependem do histórico', () {
      final now = DateTime(2026, 11, 11);
      final stats = HomeWorkoutStats([
        for (var i = 0; i < 3; i++) _log(DateTime(2026, 11, 11 - i), kcal: 200, level: i == 0 ? 'extremo' : 'leve'),
      ], now: now);
      expect(stats.earnedBadgeIds, containsAll(['first', 'streak3', 'extreme']));
      expect(stats.earnedBadgeIds, isNot(contains('five')));
      expect(stats.earnedBadgeIds, isNot(contains('kcal2500')));
    });

    test('record grava no aparelho e informa nível e conquistas novas', () async {
      final first = await HomeWorkoutProgress.instance.record(_log(DateTime.now(), xp: 120));
      expect(first.leveledUp, isTrue);
      expect(first.newBadges.map((b) => b.id), contains('first'));
      expect(first.after.totalWorkouts, 1);

      final second = await HomeWorkoutProgress.instance.record(_log(DateTime.now(), xp: 10));
      expect(second.newBadges.map((b) => b.id), isNot(contains('first')));
      expect((await HomeWorkoutProgress.instance.loadLogs()).length, 2);
    });

    test('histórico corrompido não derruba o app', () async {
      SharedPreferences.setMockInitialValues({'home_workout_logs_v1': 'não é json'});
      expect(await HomeWorkoutProgress.instance.loadLogs(), isEmpty);
      SharedPreferences.setMockInitialValues({'home_workout_logs_v1': '[1, {"a": 2}]'});
      expect(await HomeWorkoutProgress.instance.loadLogs(), isEmpty);
    });
  });

  group('telas', () {
    const mini = HomeWorkout(
      id: 'mini',
      title: 'Mini',
      subtitle: 'teste',
      level: HomeLevel.alto,
      focus: 'Teste',
      steps: [HomeStep('agachamento', 3, 2), HomeStep('prancha', 3, 0)],
    );

    Widget app(Widget home) => MaterialApp(theme: AppTheme.dark(), home: home);

    Future<void> seconds(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('treino completo: prepare-se, exercício, descanso, exercício e resumo salvo', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      var popped = false;
      await tester.pumpWidget(app(Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => const HomeWorkoutPlayerScreen(
                    workout: mini,
                    enableAudio: false,
                    enableWakelock: false,
                    getReadySeconds: 2,
                    weightKg: 70,
                  ),
                )) ??
                false;
          },
          child: const Text('abrir'),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('PREPARE-SE'), findsOneWidget);
      expect(find.text('Agachamento'), findsOneWidget);
      expect(find.text('00:02'), findsOneWidget);

      await seconds(tester, 2);
      expect(find.text('EXERCÍCIO'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);

      // Pausar congela o relógio.
      await tester.tap(find.byKey(const Key('hw-timer')));
      await tester.pump();
      await seconds(tester, 3);
      expect(find.text('PAUSADO'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hw-timer')));
      await tester.pump();
      expect(find.text('00:03'), findsOneWidget);

      await seconds(tester, 3);
      expect(find.text('DESCANSO'), findsOneWidget);
      // No descanso mostra o que vem a seguir.
      expect(find.text('Prancha'), findsOneWidget);

      await seconds(tester, 2);
      expect(find.text('EXERCÍCIO'), findsOneWidget);
      expect(find.text('Prancha'), findsOneWidget);

      await seconds(tester, 3);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('hw-summary-title')), findsOneWidget);
      expect(find.text('Treino concluído!'), findsOneWidget);
      expect(find.text('+${homeWorkoutXp(HomeLevel.alto, 2, 8)} XP'), findsOneWidget);

      // 6 s de esforço no nível Alto (7 MET) + 2 s de descanso, 70 kg.
      final logs = await HomeWorkoutProgress.instance.loadLogs();
      expect(logs, hasLength(1));
      expect(logs.single.exercises, 2);
      expect(logs.single.seconds, 8);
      expect(logs.single.kcal, kcalFor(HomeLevel.alto, 6, 2, 70));

      await tester.tap(find.byKey(const Key('hw-finish')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(popped, isTrue);
    });

    testWidgets('pular avança sem esperar e sair sem fazer nada não salva', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const HomeWorkoutPlayerScreen(
        workout: mini,
        enableAudio: false,
        enableWakelock: false,
        getReadySeconds: 5,
        weightKg: 70,
      )));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hw-skip')));
      await tester.pump();
      expect(find.text('EXERCÍCIO'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hw-close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sair do treino?'), findsOneWidget);
      expect(find.text('Encerrar e salvar'), findsNothing);
      await tester.tap(find.text('Sair'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(await HomeWorkoutProgress.instance.loadLogs(), isEmpty);
    });

    testWidgets('lista filtra por intensidade e abre a prévia do treino', (tester) async {
      tester.view.physicalSize = const Size(1080, 14000);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const HomeWorkoutsScreen()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('hw-progress-card')), findsOneWidget);
      expect(find.byKey(const Key('hw-card-leve-corpo')), findsOneWidget);
      expect(find.byKey(const Key('hw-card-extremo-tabata')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hw-filter-extremo')));
      await tester.pump();
      expect(find.byKey(const Key('hw-card-leve-corpo')), findsNothing);
      expect(find.byKey(const Key('hw-card-extremo-tabata')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hw-card-extremo-tabata')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('hw-start')), findsOneWidget);
      expect(find.text('Começar treino'), findsOneWidget);
    });
  });
}
