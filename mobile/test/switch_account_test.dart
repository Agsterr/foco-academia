import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/screens/home_screen.dart';
import 'package:foco_academia_mobile/screens/login_screen.dart';
import 'package:foco_academia_mobile/screens/staff/staff_home_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> settle(WidgetTester t, [int times = 5]) async {
  for (var i = 0; i < times; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'last_successful_online_auth_at': DateTime.now().toUtc().toIso8601String(),
    });
    AuthService.instance
      ..token = 't'
      ..deviceId = 'd'
      ..userName = 'Ajhovane'
      ..role = 'ALUNO'
      ..academySlug = 'academia-da-conta-anterior';
  });

  Widget app(Widget home) => MaterialApp(theme: AppTheme.dark(), home: home);

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('entrada: título claro e o código da academia de uma conta anterior não vem preenchido', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const LoginScreen()));
    await settle(tester, 2);
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    expect(find.text('Entrar na sua conta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    final slugField = tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(slugField.controller!.text, isEmpty, reason: 'o código antigo fazia a entrada de outra conta falhar');
  });

  testWidgets('cadastro: "Já tenho conta. Entrar" volta para a tela de entrada', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(const LoginScreen()));
    await settle(tester, 2);
    await tester.ensureVisible(find.byKey(const Key('open-register')));
    await tester.tap(find.byKey(const Key('open-register')));
    await settle(tester, 3);
    expect(find.text('Criar conta'), findsWidgets);
    expect(find.byKey(const Key('login-title')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('have-account')));
    await tester.tap(find.byKey(const Key('have-account')));
    await settle(tester, 3);
    expect(find.byKey(const Key('login-title')), findsOneWidget);
  });

  testWidgets('aluno: "Trocar de conta" pede confirmação, sai da conta e abre a entrada', (tester) async {
    phone(tester);
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const HomeScreen()));
      await settle(tester);
      final tile = find.byKey(const Key('switch-account'));
      await tester.scrollUntilVisible(tile, 300, scrollable: find.byType(Scrollable).first);
      await settle(tester, 3); // deixa a rolagem terminar antes de tocar
      await tester.tap(tile);
      await settle(tester, 2);
      expect(find.text('Trocar de conta?'), findsOneWidget);

      // Cancelar não sai da conta.
      await tester.tap(find.text('Cancelar'));
      await settle(tester, 2);
      expect(AuthService.instance.token, 't');
      expect(find.byKey(const Key('login-title')), findsNothing);

      await settle(tester, 3);
      await tester.tap(tile);
      await settle(tester, 2);
      await tester.tap(find.byKey(const Key('switch-account-confirm')));
      await settle(tester);
      expect(AuthService.instance.token, isNull);
      expect(find.byKey(const Key('login-title')), findsOneWidget);
    }, () => MockClient((r) async => _json({}, 200)));
  });

  testWidgets('academia/personal: botão "Sair" com nome leva à entrada', (tester) async {
    phone(tester);
    AuthService.instance.role = 'GESTOR';
    await http.runWithClient(() async {
      await tester.pumpWidget(app(const StaffHomeScreen()));
      await settle(tester);
      expect(find.text('Sair'), findsOneWidget, reason: 'só o ícone passava despercebido');
      await tester.tap(find.byKey(const Key('staff-logout')));
      await settle(tester);
      expect(AuthService.instance.token, isNull);
      expect(find.byKey(const Key('login-title')), findsOneWidget);
    }, () => MockClient((r) async => _json({'message': 'Sem acesso agora'}, 500)));
  });
}
