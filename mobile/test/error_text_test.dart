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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('errorText tira o prefixo técnico e mantém a mensagem', () {
    expect(errorText(Exception('Perfil não encontrado')), 'Perfil não encontrado');
    expect(errorText('Exception:   Erro interno  '), 'Erro interno');
    expect(errorText(StateError('falhou')), 'Bad state: falhou');
    expect(errorText('Sem rede'), 'Sem rede');
  });

  testWidgets('Perfil físico: conta sem perfil abre vazia e o erro de salvar não mostra "Exception:"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 't'
      ..deviceId = 'd'
      ..userName = 'Mariana Irmã'
      ..role = 'ALUNO';
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const ProfileScreen()));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('Perfil não encontrado'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Salvar'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Serviço indisponível no momento'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
    }, () => MockClient((r) async {
          if (r.method == 'GET' && r.url.path == '/api/student/profile') return _json({'message': 'Perfil não encontrado'}, 400);
          if (r.method == 'PUT' && r.url.path == '/api/student/profile') return _json({'message': 'Serviço indisponível no momento'}, 400);
          return _json({}, 200);
        }));
  });

  testWidgets('Perfil físico: conta sem perfil preenche (data DD/MM/AAAA) e salva com sucesso', (tester) async {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 't'
      ..deviceId = 'd'
      ..userName = 'Mariana Irmã'
      ..role = 'ALUNO';
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    Map<String, dynamic>? sent;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: const Text('abrir perfil'),
          ),
        ),
      ));
      await tester.tap(find.text('abrir perfil'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.textContaining('Perfil não encontrado'), findsNothing);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '81,5');
      await tester.enterText(fields.at(1), '165');
      await tester.enterText(fields.at(2), '27/06/1992');
      await tester.tap(find.text('Salvar'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(sent, isNotNull);
      expect(sent!['weightKg'], 81.5);
      expect(sent!['heightCm'], 165);
      expect(sent!['birthDate'], '1992-06-27');
      expect(find.byType(ProfileScreen), findsNothing, reason: 'volta para a tela anterior depois de salvar');
    }, () => MockClient((r) async {
          if (r.method == 'GET' && r.url.path == '/api/student/profile') return _json({'message': 'Perfil não encontrado'}, 400);
          if (r.method == 'PUT' && r.url.path == '/api/student/profile') {
            sent = jsonDecode(r.body) as Map<String, dynamic>;
            return _json({'studentId': 'u1', 'studentName': 'Mariana', 'heightCm': 165, 'currentWeightKg': 81.5}, 200);
          }
          return _json({}, 200);
        }));
  });
}
