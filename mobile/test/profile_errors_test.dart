import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/core/ui/error_text.dart';
import 'package:foco_academia_mobile/screens/profile_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> settle(WidgetTester t, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<void> tapSave(WidgetTester t) async {
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

  group('errorText', () {
    test('internet, demora e resposta estranha viram frases que dizem o que fazer', () {
      expect(errorText(http.ClientException('SocketException: Failed host lookup: x')), contains('Sem conexão com a internet'));
      expect(errorText(Exception('Connection refused')), contains('Sem conexão com a internet'));
      expect(errorText(TimeoutException('x')), contains('conexão está lenta'));
      expect(errorText(const FormatException('<html>')), contains('respondeu algo inesperado'));
    });

    test('códigos de erro sem mensagem do servidor', () {
      expect(errorText(Exception('Erro 500')), contains('problema agora'));
      expect(errorText(Exception('Erro 503')), contains('problema agora'));
      expect(errorText(Exception('Erro 403')), contains('permissão'));
      expect(errorText(Exception('Erro 429')), contains('Muitas tentativas'));
      expect(errorText(Exception('Erro 404')), contains('erro 404'));
    });

    test('mensagem clara do servidor é mantida e o prefixo técnico some', () {
      expect(errorText(Exception('Altura deve estar entre 50 e 250 cm')), 'Altura deve estar entre 50 e 250 cm');
      expect(errorText('Exception:   Sem acesso '), 'Sem acesso');
    });
  });

  group('tela de perfil', () {
    void phone(WidgetTester t) {
      t.view.physicalSize = const Size(1080, 5400); // formulário inteiro visível, sem rolagem
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
    }

    Future<void> run(WidgetTester tester, MockClientHandler handler, Future<void> Function() body) async {
      phone(tester);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const ProfileScreen()));
        await settle(tester);
        await body();
      }, () => MockClient(handler));
    }

    testWidgets('sem internet ao abrir: aviso claro e "Tentar de novo" carrega quando a internet volta', (tester) async {
      var online = false;
      await run(tester, (r) async {
        if (!online) throw http.ClientException('SocketException: Failed host lookup: academia');
        if (r.method == 'GET' && r.url.path == '/api/student/profile') {
          return _json({'studentId': 'u', 'studentName': 'M', 'heightCm': 170, 'currentWeightKg': 70.5}, 200);
        }
        return _json({}, 200);
      }, () async {
        expect(find.textContaining('Sem conexão com a internet'), findsOneWidget);
        expect(find.textContaining('Exception'), findsNothing);
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.byKey(const Key('profile-retry')), findsOneWidget);

        online = true;
        await tester.tap(find.byKey(const Key('profile-retry')));
        await settle(tester);
        expect(find.byKey(const Key('profile-error')), findsNothing);
        expect(tester.widget<TextField>(find.byKey(const Key('height-field'))).controller!.text, '170');
        expect(tester.widget<TextField>(find.byKey(const Key('weight-field'))).controller!.text, '70,5');
      });
    });

    testWidgets('erro 500 ao salvar: avisa que o servidor está com problema e dá para tentar de novo', (tester) async {
      var puts = 0;
      await run(tester, (r) async {
        if (r.method == 'GET') return _json({'message': 'Perfil não encontrado'}, 400);
        puts++;
        return puts == 1 ? http.Response('', 500) : _json({'studentId': 'u', 'studentName': 'M'}, 200);
      }, () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '78');
        await tapSave(tester);
        await settle(tester);
        expect(find.textContaining('servidor está com problema'), findsOneWidget);
        expect(find.textContaining('Erro 500'), findsNothing);
        expect(find.byKey(const Key('profile-retry')), findsNothing, reason: 'tentar de novo só aparece quando o carregamento falha');
        expect(find.text('Salvar'), findsOneWidget, reason: 'o botão volta a funcionar');

        await tapSave(tester);
        await settle(tester);
        expect(puts, 2);
        expect(find.byType(ProfileScreen), findsNothing, reason: 'salvou e voltou');
      });
    });

    testWidgets('internet cai na hora de salvar: aviso claro, sem texto técnico', (tester) async {
      await run(tester, (r) async {
        if (r.method == 'GET') return _json({'message': 'Perfil não encontrado'}, 400);
        throw http.ClientException('SocketException: Connection reset by peer');
      }, () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '78');
        await tapSave(tester);
        await settle(tester);
        expect(find.textContaining('Sem conexão com a internet'), findsOneWidget);
        expect(find.textContaining('SocketException'), findsNothing);
        expect(find.text('Salvar'), findsOneWidget);
      });
    });

    testWidgets('servidor que não responde: depois de 20 s avisa que a conexão está lenta e libera o botão', (tester) async {
      final never = Completer<http.Response>();
      await run(tester, (r) {
        if (r.method == 'GET') return Future.value(_json({'message': 'Perfil não encontrado'}, 400));
        return never.future;
      }, () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '78');
        await tapSave(tester);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Salvando...'), findsOneWidget);
        await tester.pump(const Duration(seconds: 25));
        await settle(tester);
        expect(find.textContaining('conexão está lenta'), findsOneWidget);
        expect(find.text('Salvar'), findsOneWidget);
      });
    });
  });
}
