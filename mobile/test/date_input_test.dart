import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/core/ui/date_input.dart';
import 'package:foco_academia_mobile/screens/profile_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simula a pessoa digitando tecla por tecla ("<" apaga o último caractere).
String type(String keys, {String start = ''}) {
  const formatter = BrDateInputFormatter();
  var value = TextEditingValue(text: start, selection: TextSelection.collapsed(offset: start.length));
  for (final key in keys.split('')) {
    final text = key == '<' ? (value.text.isEmpty ? '' : value.text.substring(0, value.text.length - 1)) : value.text + key;
    value = formatter.formatEditUpdate(value, TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)));
  }
  return value.text;
}

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('máscara DD/MM/AAAA', () {
    test('as barras entram sozinhas', () {
      expect(type('27061992'), '27/06/1992');
      expect(type('27'), '27/');
      expect(type('270'), '27/0');
      expect(type('2706'), '27/06/');
      expect(type('27061'), '27/06/1');
    });

    test('só números: letras, hífens e barras digitadas são ignorados', () {
      expect(type('2a7-0/6x1992'), '27/06/1992');
      expect(type('abc'), '');
    });

    test('número que não cabe no dia ou no mês é corrigido ou recusado', () {
      expect(type('5'), '05/'); // dia 5 vira 05
      expect(type('9'), '09/');
      expect(type('32'), '3'); // não existe dia 32
      expect(type('00'), '0'); // nem dia 00
      expect(type('2713'), '27/1'); // nem mês 13
      expect(type('270'), '27/0');
      expect(type('2700'), '27/0'); // nem mês 00
      expect(type('277'), '27/07/'); // mês 7 vira 07
      expect(type('31'), '31/');
    });

    test('não passa de 8 números', () {
      expect(type('270619921234'), '27/06/1992');
    });

    test('apagar funciona e a barra não prende', () {
      expect(type('27<'), '27'); // apaga a barra e o cursor fica no 7
      expect(type('27<<'), '2');
      expect(type('27/06/1992<'), '27/06/199');
      expect(type('27/06/1992<<<<<'), '27/0'); // a barra some sozinha ao apagar
      expect(type('2706<'), '27/06');
      expect(type('2706<<'), '27/0');
      expect(type('27<0'), '270'.replaceFirst('270', '27/0')); // depois de apagar, continua digitando normalmente
    });

    test('colar a data inteira (com ou sem barras) também formata', () {
      const formatter = BrDateInputFormatter();
      for (final pasted in ['27/06/1992', '27061992', '27-06-1992', ' 27.06.1992 ']) {
        final out = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: pasted, selection: TextSelection.collapsed(offset: pasted.length)),
        );
        expect(out.text, '27/06/1992', reason: pasted);
      }
    });
  });

  group('validação', () {
    final now = DateTime(2026, 11, 13);

    test('vazio e incompleto não mostram erro enquanto a pessoa digita', () {
      expect(checkBirthDate('', now: now).error, isNull);
      expect(checkBirthDate('27/06', now: now).error, isNull);
      expect(checkBirthDate('27/06', now: now).complete, isFalse);
    });

    test('data completa e válida', () {
      final ok = checkBirthDate('27/06/1992', now: now);
      expect(ok.isValid, isTrue);
      expect(ok.date, DateTime(1992, 6, 27));
    });

    test('dia que não existe, futuro e ano muito antigo', () {
      expect(checkBirthDate('31/02/1992', now: now).error, contains('não existe'));
      expect(checkBirthDate('29/02/2023', now: now).error, contains('não existe'));
      expect(checkBirthDate('29/02/2024', now: now).isValid, isTrue); // ano bissexto
      expect(checkBirthDate('14/11/2026', now: now).error, contains('futuro'));
      expect(checkBirthDate('13/11/2026', now: now).isValid, isTrue); // hoje vale
      expect(checkBirthDate('01/01/1850', now: now).error, contains('1900'));
    });
  });

  group('campo na tela de perfil', () {
    Future<List<Map<String, dynamic>>> openProfile(WidgetTester tester, Future<void> Function(List<Map<String, dynamic>> puts) body) async {
      SharedPreferences.setMockInitialValues({});
      AuthService.instance
        ..token = 't'
        ..deviceId = 'd'
        ..userName = 'Mariana Irmã'
        ..role = 'ALUNO';
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final puts = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const ProfileScreen()));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await body(puts);
      }, () => MockClient((r) async {
            if (r.method == 'GET' && r.url.path == '/api/student/profile') return _json({'message': 'Perfil não encontrado'}, 400);
            if (r.method == 'PUT' && r.url.path == '/api/student/profile') {
              puts.add(jsonDecode(r.body) as Map<String, dynamic>);
              return _json({'studentId': 'u', 'studentName': 'M'}, 200);
            }
            return _json({}, 200);
          }));
      return puts;
    }

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('mostra como preencher e formata sozinho ao digitar só números', (tester) async {
      await openProfile(tester, (_) async {
        expect(find.textContaining('Ex.: 27/06/1992'), findsOneWidget);
        expect(find.byTooltip('Abrir calendário'), findsOneWidget);
        await tester.enterText(find.byKey(const Key('birth-field')), '27061992');
        await tester.pump();
        expect(tester.widget<TextField>(find.byKey(const Key('birth-field'))).controller!.text, '27/06/1992');
      });
    });

    testWidgets('dia que não existe mostra o erro no campo e não salva', (tester) async {
      final puts = await openProfile(tester, (puts) async {
        await tester.enterText(find.byKey(const Key('birth-field')), '31021992');
        await tester.pump();
        expect(find.textContaining('Esse dia não existe'), findsOneWidget);
        await tester.tap(find.text('Salvar'));
        await settle(tester);
        expect(puts, isEmpty);
        expect(find.byType(ProfileScreen), findsOneWidget);
      });
      expect(puts, isEmpty);
    });

    testWidgets('data pela metade avisa ao salvar e some quando a pessoa volta a digitar', (tester) async {
      await openProfile(tester, (puts) async {
        await tester.enterText(find.byKey(const Key('birth-field')), '2706');
        await tester.pump();
        expect(find.textContaining('Complete a data'), findsNothing, reason: 'sem erro enquanto digita');
        await tester.tap(find.text('Salvar'));
        await settle(tester);
        expect(find.textContaining('Complete a data'), findsOneWidget);
        expect(puts, isEmpty);
        await tester.enterText(find.byKey(const Key('birth-field')), '27061');
        await settle(tester); // o aviso some com uma animação curta
        expect(find.textContaining('Complete a data'), findsNothing);
      });
    });

    testWidgets('campo de data vazio salva normalmente (a data é opcional)', (tester) async {
      final puts = await openProfile(tester, (puts) async {
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), '70');
        await tester.enterText(fields.at(1), '170');
        await tester.tap(find.text('Salvar'));
        await settle(tester);
      });
      expect(puts, hasLength(1));
      expect(puts.single['birthDate'], isNull);
    });

    testWidgets('calendário abre no ano e preenche o campo', (tester) async {
      await openProfile(tester, (puts) async {
        await tester.tap(find.byKey(const Key('birth-calendar')));
        await settle(tester);
        expect(find.text('Data de nascimento'), findsWidgets);
        expect(find.text('Escolher'), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
        final initialYear = DateTime.now().year - 25;
        await tester.tap(find.text('$initialYear'));
        await tester.pump();
        await tester.tap(find.text('Escolher'));
        await settle(tester);
        expect(tester.widget<TextField>(find.byKey(const Key('birth-field'))).controller!.text, '01/01/$initialYear');
      });
    });
  });
}
