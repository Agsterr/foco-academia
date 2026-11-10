import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
import 'package:foco_academia_mobile/screens/invite_screen.dart';
import 'package:foco_academia_mobile/screens/login_screen.dart';
import 'package:foco_academia_mobile/screens/staff/staff_home_screen.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/invite_link.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  String? password;

  @override
  Future<void> deletePassword() async => password = null;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> writePassword(String value) async => password = value;
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

const _preview = {
  'code': 'K7Q2MX9P3T',
  'role': 'ALUNO',
  'academyName': 'Studio Fulano',
  'instructorName': 'Fulano Personal',
  'invitedBy': 'Fulano Personal',
  'name': 'Bruno Lima',
  'personal': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = null
      ..role = null
      ..deviceId = 'android-abc123'
      ..credentialStore = _MemoryCredentialStore();
  });

  group('link do convite', () {
    test('lê o código do link do app, do link do site e do código digitado', () {
      expect(InviteLinks.codeFrom('focoacademia://convite/K7Q2M-X9P3T'), 'K7Q2MX9P3T');
      expect(InviteLinks.codeFrom('https://academia.focodev.com.br/convite/k7q2mx9p3t'), 'K7Q2MX9P3T');
      expect(InviteLinks.codeFrom('https://academia.focodev.com.br/treinos'), isNull);
      expect(InviteLinks.codeFrom('focoacademia://convite/'), isNull);
      expect(InviteLinks.codeFrom(null), isNull);
      expect(InviteLinks.normalizeCode(' k7q2m x9p3t '), 'K7Q2MX9P3T');
    });
  });

  group('aceitar convite', () {
    testWidgets('mostra quem convidou, cria a conta neste aparelho e entra', (tester) async {
      final calls = <http.Request>[];
      final client = MockClient((request) async {
        calls.add(request);
        if (request.method == 'GET') return _json(_preview);
        return _json({
          'token': 'novo-token',
          'academySlug': 'studio-fulano',
          'linkedExistingAccount': false,
          'user': {'id': 'u1', 'name': 'Bruno Lima', 'role': 'ALUNO'},
        });
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const InviteScreen(code: 'K7Q2MX9P3T')));
        await tester.pumpAndSettle();

        expect(find.text('Treine com Fulano Personal'), findsOneWidget);
        // O nome que o instrutor digitou já vem preenchido.
        expect(find.widgetWithText(TextFormField, 'Bruno Lima'), findsOneWidget);

        await tester.enterText(find.byKey(const Key('invite-email')), 'Bruno@X.com');
        await tester.enterText(find.byKey(const Key('invite-password')), 'segredo123');
        await tester.enterText(find.byKey(const Key('invite-confirm')), 'segredo123');
        await tester.ensureVisible(find.byKey(const Key('invite-accept')));
        await tester.tap(find.byKey(const Key('invite-accept')));
        // A tela inicial do aluno carrega coisas que não importam aqui.
        await tester.pump(const Duration(milliseconds: 300));
      }, () => client);

      final accept = calls.firstWhere((c) => c.method == 'POST');
      expect(accept.url.path, '/api/auth/invites/K7Q2MX9P3T/accept');
      final body = jsonDecode(accept.body) as Map<String, dynamic>;
      expect(body['email'], 'bruno@x.com');
      expect(body['name'], 'Bruno Lima');
      expect(body['deviceId'], 'android-abc123');
      expect(AuthService.instance.token, 'novo-token');
      expect(AuthService.instance.role, 'ALUNO');
      // Login lembrado já com a academia: entra de novo sozinho.
      final saved = await AuthService.instance.savedCredentials();
      expect(saved!.slug, 'studio-fulano');
      expect(saved.password, 'segredo123');
    });

    testWidgets('quem já tem conta vincula só com e-mail e senha', (tester) async {
      Map<String, dynamic>? sent;
      final client = MockClient((request) async {
        if (request.method == 'GET') return _json(_preview);
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'message': 'Este e-mail já tem conta no app. Digite a senha dela para vincular à academia.'}, 400);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const InviteScreen(code: 'K7Q2MX9P3T')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('invite-has-account')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('invite-name')), findsNothing);
        expect(find.byKey(const Key('invite-confirm')), findsNothing);

        await tester.enterText(find.byKey(const Key('invite-email')), 'carla@x.com');
        await tester.enterText(find.byKey(const Key('invite-password')), 'errada1');
        await tester.ensureVisible(find.byKey(const Key('invite-accept')));
        await tester.tap(find.byKey(const Key('invite-accept')));
        await tester.pumpAndSettle();
      }, () => client);

      expect(sent!.containsKey('name'), isFalse);
      expect(find.textContaining('Digite a senha dela'), findsOneWidget);
    });

    testWidgets('link já usado avisa e não mostra formulário', (tester) async {
      final client = MockClient((_) async => _json(
          {'message': 'Este convite já foi usado. Cada convite vale para uma pessoa só; peça um novo.'}, 410));
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const InviteScreen(code: 'USADO12345')));
        await tester.pumpAndSettle();
      }, () => client);
      expect(find.textContaining('já foi usado'), findsOneWidget);
      expect(find.byKey(const Key('invite-accept')), findsNothing);
    });

    testWidgets('no login, "Tenho um código de convite" aceita o link colado', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      final client = MockClient((_) async => _json(_preview));
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const LoginScreen()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('have-invite')));
        await tester.tap(find.byKey(const Key('have-invite')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('invite-code-field')), 'oi');
        await tester.tap(find.byKey(const Key('invite-code-ok')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Digite o código'), findsOneWidget);

        await tester.enterText(
            find.byKey(const Key('invite-code-field')), 'https://academia.focodev.com.br/convite/K7Q2M-X9P3T');
        await tester.tap(find.byKey(const Key('invite-code-ok')));
        await tester.pumpAndSettle();
      }, () => client);
      expect(find.byType(InviteScreen), findsOneWidget);
      expect(find.text('Treine com Fulano Personal'), findsOneWidget);
    });
  });

  group('instrutor convida', () {
    testWidgets('gera o link e mostra o código para mandar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.6;
      addTearDown(tester.view.reset);
      AuthService.instance
        ..token = 'token'
        ..role = 'INSTRUTOR';
      final calls = <http.Request>[];
      final client = MockClient((request) async {
        calls.add(request);
        final path = request.url.path;
        if (path == '/api/manager/access') {
          return _json({'manager': false, 'personal': false, 'academyName': 'Academia X'});
        }
        if (path == '/api/manager/invites' && request.method == 'POST') {
          return _json({
            'id': 'i1',
            'code': 'K7Q2MX9P3T',
            'url': 'https://academia.focodev.com.br/convite/K7Q2MX9P3T',
            'role': 'ALUNO',
            'name': 'Bruno',
            'instructorName': 'Ana',
            'expiresAt': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
            'shareText': 'Oi, Bruno! ...',
          });
        }
        if (path == '/api/auth/heartbeat') return http.Response('', 204);
        if (path == '/api/auth/refresh') return _json({'token': 'token'});
        return _json([]);
      });

      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(theme: AppTheme.dark(), home: const StaffHomeScreen()));
        await tester.pumpAndSettle();
        // Instrutor de academia vai direto para o convite (sem a opção de cadastrar com senha).
        await tester.tap(find.byKey(const Key('new-student')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('invite-name-field')), 'Bruno');
        await tester.tap(find.byKey(const Key('create-invite')));
        await tester.pumpAndSettle();
      }, () => client);

      final create = calls.singleWhere((c) => c.url.path == '/api/manager/invites' && c.method == 'POST');
      expect(jsonDecode(create.body), {'role': 'ALUNO', 'name': 'Bruno'});
      expect(find.text('K7Q2M-X9P3T'), findsOneWidget);
      expect(find.byKey(const Key('share-invite')), findsOneWidget);
    });
  });
}
