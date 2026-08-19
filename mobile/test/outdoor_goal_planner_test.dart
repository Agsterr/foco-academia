import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foco_academia_mobile/services/outdoor_goal.dart';
import 'package:foco_academia_mobile/widgets/outdoor_goal_planner.dart';

class _PlannerHarness extends StatefulWidget {
  const _PlannerHarness({this.initial = const OutdoorGoal()});

  final OutdoorGoal initial;

  @override
  State<_PlannerHarness> createState() => _PlannerHarnessState();
}

class _PlannerHarnessState extends State<_PlannerHarness> {
  late OutdoorGoal goal;

  @override
  void initState() {
    super.initState();
    goal = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return OutdoorGoalPlanner(
      weightKg: 79.2,
      heightCm: 165,
      usingDefaultWeight: false,
      hasCoachPlan: false,
      goal: goal,
      onChanged: (g) => setState(() => goal = g),
    );
  }
}

Widget _app(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2563EB),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('intervalado permite km livre além de 5 e 10', (tester) async {
    await tester.pumpWidget(_app(const _PlannerHarness()));

    await tester.tap(find.text('Intervalado'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('interval-km-field')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('interval-km-field')), '7.5');
    await tester.pump();

    expect(find.textContaining('7.5 km'), findsWidgets);
    expect(find.textContaining('até 5 km'), findsNothing);
  });

  testWidgets('intervalado aceita tempo livre em minutos', (tester) async {
    await tester.pumpWidget(
      _app(
        const _PlannerHarness(
          initial: OutdoorGoal(mode: OutdoorGoalMode.intervals, targetKm: 5),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('interval-min-field')), '40');
    await tester.pump();

    expect(find.textContaining('40 min'), findsWidgets);
  });
}
