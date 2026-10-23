import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryStore implements CredentialStore {
  String? password;

  @override
  Future<void> deletePassword() async => password = null;

  @override
  Future<String?> readPassword() async => password;

  @override
  Future<void> writePassword(String value) async => password = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryStore store;
  late List<Map<String, dynamic>> logins;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _MemoryStore();
    logins = [];
    AuthService.instance
      ..credentialStore = store
      ..token = 'token-vencido';
  });

  /// API em que o token antigo venceu de vez (refresh → 401) e o login devolve um novo.
  MockClient api() => MockClient((request) async {
        switch (request.url.path) {
          case '/api/auth/refresh':
            return http.Response('{"message":"Sessão expirada"}', 401);
          case '/api/auth/login':
            logins.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(jsonEncode({'token': 'token-novo'}), 200);
        }
        if (request.headers['Authorization'] != 'Bearer token-novo') {
          return http.Response('{}', 401);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });

  test('login lembrado: token vencido entra de novo sozinho e a requisição continua', () async {
    await http.runWithClient(() async {
      await AuthService.instance.login('aluno@academia.com', 'segredo', 'minha-academia');
      AuthService.instance.token = 'token-vencido';
      logins.clear();

      final result = await AuthService.instance.get('/api/student/stats');
      expect(result['ok'], isTrue);
    }, api);

    expect(AuthService.instance.token, 'token-novo');
    expect(logins, hasLength(1));
    expect(logins.single['email'], 'aluno@academia.com');
    expect(logins.single['password'], 'segredo');
    expect(logins.single['academySlug'], 'minha-academia');
  });

  test('sem login lembrado: token vencido leva ao login', () async {
    await http.runWithClient(() async {
      await expectLater(
        AuthService.instance.get('/api/student/stats'),
        throwsA(isA<SessionExpiredException>()),
      );
    }, api);

    expect(AuthService.instance.token, isNull);
    expect(logins, isEmpty);
  });

  test('desmarcar "lembrar" apaga a senha guardada', () async {
    await http.runWithClient(() async {
      await AuthService.instance.login('aluno@academia.com', 'segredo', 'minha-academia');
      expect(await AuthService.instance.savedCredentials(), isNotNull);
      expect(store.password, 'segredo');

      await AuthService.instance.login('aluno@academia.com', 'segredo', 'minha-academia', remember: false);
    }, api);

    expect(store.password, isNull);
    expect(await AuthService.instance.savedCredentials(), isNull);
  });

  test('validação online (48h) com token vencido renova pelo login lembrado', () async {
    await http.runWithClient(() async {
      await AuthService.instance.login('aluno@academia.com', 'segredo', 'minha-academia');
      AuthService.instance.token = 'token-vencido';

      final ok = await AuthService.instance.ensureOnlineSession();
      expect(ok, isTrue);
    }, () => MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') return http.Response('{}', 401);
          if (request.url.path == '/api/auth/login') {
            return http.Response(jsonEncode({'token': 'token-novo'}), 200);
          }
          return http.Response('{}', 200);
        }));

    expect(AuthService.instance.token, 'token-novo');
  });
}
