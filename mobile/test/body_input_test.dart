import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/core/ui/body_input.dart';
import 'package:foco_academia_mobile/screens/profile_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// O formulário é mais alto que a tela: rola até o botão Salvar antes de tocar.
Future<void> tapSave(WidgetTester t) async {
  await t.scrollUntilVisible(find.text('Salvar'), 300, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 600));
  await t.tap(find.text('Salvar'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 't'
      ..deviceId = 'd'
      ..userName = 'Mariana'
      ..role = 'ALUNO';
  });

  group('altura', () {
    test('em centímetros passa direto, com vírgula ou ponto', () {
      expect(checkHeightCm('170').value, 170);
      expect(checkHeightCm('170,5').value, 170.5);
      expect(checkHeightCm('170.5').value, 170.5);
      expect(checkHeightCm('170').convertedFromMeters, isFalse);
    });

    test('em metros (1,60) é convertido para centímetros', () {
      final h = checkHeightCm('1,60');
      expect(h.value, 160);
      expect(h.convertedFromMeters, isTrue);
      expect(checkHeightCm('1.70').value, 170);
      expect(checkHeightCm('1,755').value, 175.5);
      expect(checkHeightCm('2,5').value, 250); // 2,5 m é o limite
    });

    test('fora da faixa tem erro claro', () {
      for (final text in ['30', '49', '251', '300', '2,99', '0,4']) {
        final h = checkHeightCm(text);
        expect(h.isValid, isFalse, reason: text);
        expect(h.error, contains('entre 50 e 250 cm'), reason: text);
      }
      expect(checkHeightCm('abc').error, contains('só números'));
    });

    test('vazio não é erro (o campo é opcional)', () {
      expect(checkHeightCm('').isValid, isTrue);
      expect(checkHeightCm('  ').value, isNull);
    });
  });

  group('peso', () {
    test('valores válidos', () {
      expect(checkWeightKg('78').value, 78);
      expect(checkWeightKg('78,5').value, 78.5);
      expect(checkWeightKg('20').isValid, isTrue);
      expect(checkWeightKg('500').isValid, isTrue);
      expect(checkWeightKg('').isValid, isTrue);
    });

    test('fora da faixa e texto têm erro claro', () {
      expect(checkWeightKg('5').error, contains('entre 20 e 500 kg'));
      expect(checkWeightKg('501').error, contains('entre 20 e 500 kg'));
      expect(checkWeightKg('x').error, contains('só números'));
    });
  });

  test('formatCm usa vírgula e só mostra decimal quando precisa', () {
    expect(formatCm(160), '160');
    expect(formatCm(175.5), '175,5');
    expect(formatKg(78), '78');
    expect(formatKg(70.5), '70,5');
    expect(formatKg(78.04), '78'); // uma casa decimal, sem ",0"
  });

  group('erro de validação do servidor', () {
    Future<Object?> update(http.Response response) async {
      Object? caught;
      await http.runWithClient(() async {
        try {
          await ProfileService.instance.updateProfile(heightCm: 1.6);
        } catch (e) {
          caught = e;
        }
      }, () => MockClient((_) async => response));
      return caught;
    }

    test('mostra o motivo do campo em vez de "Erro 400"', () async {
      final e = await update(_json({'heightCm': 'Altura deve estar entre 50 e 250 cm'}, 400));
      expect(e.toString(), contains('Altura deve estar entre 50 e 250 cm'));
      expect(e.toString(), isNot(contains('Erro 400')));
    });

    test('com "message" usa a mensagem', () async {
      final e = await update(_json({'message': 'Altura inválida', 'heightCm': 'x'}, 400));
      expect(e.toString(), contains('Altura inválida'));
    });

    test('sem corpo útil continua mostrando o código', () async {
      final e = await update(http.Response('', 400));
      expect(e.toString(), contains('Erro 400'));
    });
  });

  group('tela de perfil', () {
    Future<List<Map<String, dynamic>>> open(WidgetTester tester, Future<void> Function() body) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final puts = <Map<String, dynamic>>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const ProfileScreen()));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        await body();
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

    testWidgets('altura digitada em metros (1,60) é salva como 160 cm', (tester) async {
      final puts = await open(tester, () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '78');
        await tester.enterText(find.byKey(const Key('height-field')), '1,60');
        await settle(tester);
        expect(find.textContaining('Entendi 1,60 m como 160 cm'), findsOneWidget);
        await tapSave(tester);
        await settle(tester);
      });
      expect(puts, hasLength(1));
      expect(puts.single['heightCm'], 160);
      expect(puts.single['weightKg'], 78);
    });

    testWidgets('altura ou peso impossíveis mostram o erro no campo e não enviam', (tester) async {
      final puts = await open(tester, () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '5');
        await tester.enterText(find.byKey(const Key('height-field')), '30');
        await tapSave(tester);
        await settle(tester);
        expect(find.textContaining('Altura deve estar entre 50 e 250 cm'), findsOneWidget);
        expect(find.textContaining('Peso deve estar entre 20 e 500 kg'), findsOneWidget);
        expect(find.byType(ProfileScreen), findsOneWidget);

        // Corrigir o campo limpa o aviso daquele campo.
        await tester.enterText(find.byKey(const Key('height-field')), '170');
        await settle(tester);
        expect(find.textContaining('Altura deve estar entre 50 e 250 cm'), findsNothing);
        expect(find.textContaining('Peso deve estar entre 20 e 500 kg'), findsOneWidget);
      });
      expect(puts, isEmpty);
    });

    testWidgets('não deixa digitar letras nos campos de peso e altura', (tester) async {
      await open(tester, () async {
        await tester.enterText(find.byKey(const Key('height-field')), '1a7b0');
        await tester.enterText(find.byKey(const Key('weight-field')), '7x8,5');
        expect(tester.widget<TextField>(find.byKey(const Key('height-field'))).controller!.text, '170');
        expect(tester.widget<TextField>(find.byKey(const Key('weight-field'))).controller!.text, '78,5');
      });
    });
  });
}
