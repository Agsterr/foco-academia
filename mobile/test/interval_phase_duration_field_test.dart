import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/widgets/interval_phase_duration_field.dart';

void main() {
  // A fonte de teste do Flutter desenha cada caractere com 1 em de largura,
  // quase o dobro de uma fonte real: se cabe aqui, cabe com folga no celular.
  // Mesma largura do print: celular de ~390 px, card com margens, dois campos lado a lado.
  Future<void> pumpPair(WidgetTester tester, {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(390, 900), textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                Expanded(
                  child: IntervalPhaseDurationField(label: 'Caminhada', seconds: 180, onChanged: (_) {}),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IntervalPhaseDurationField(label: 'Corrida', seconds: 19 * 60, onChanged: (_) {}),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  void expectValueFits(WidgetTester tester, String value) {
    final index = value == '3:00' ? 0 : 1;
    final editableText = find.byType(EditableText).at(index);
    final editable = tester.renderObject<RenderEditable>(
      find.descendant(of: editableText, matching: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Editable')),
    );
    final painter = TextPainter(
      text: editable.text,
      textDirection: TextDirection.ltr,
      textScaler: editable.textScaler,
    )..layout();
    expect(editable.size.width, greaterThanOrEqualTo(painter.width),
        reason: '"$value" precisa caber inteiro no campo');
  }

  testWidgets('3:00 e 19:00 aparecem inteiros lado a lado', (tester) async {
    await pumpPair(tester);
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('19:00'), findsOneWidget);
    expectValueFits(tester, '3:00');
    expectValueFits(tester, '19:00');
    expect(tester.takeException(), isNull);
  });

}
