import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.token = 'token-antigo';
  });

  test('requisições simultâneas com token expirado aguardam o mesmo refresh', () async {
    var refreshCalls = 0;
    final release = Completer<void>();
    final client = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh') {
        refreshCalls++;
        await release.future;
        return http.Response(jsonEncode({'token': 'token-novo'}), 200);
      }
      if (request.headers['Authorization'] != 'Bearer token-novo') {
        return http.Response('{}', 401);
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await http.runWithClient(() async {
      final first = AuthService.instance.get('/api/student/stats');
      final second = AuthService.instance.get('/api/student/profile');
      await Future<void>.delayed(Duration.zero);
      release.complete();
      final results = await Future.wait([first, second]);
      expect(results.map((r) => r['ok']), [true, true]);
    }, () => client);

    expect(refreshCalls, 1);
    expect(AuthService.instance.token, 'token-novo');
  });

  test('novo refresh após o anterior terminar chama a API de novo', () async {
    var refreshCalls = 0;
    final client = MockClient((request) async {
      refreshCalls++;
      return http.Response(jsonEncode({'token': 'token-$refreshCalls'}), 200);
    });

    await http.runWithClient(() async {
      expect(await AuthService.instance.refreshSession(), isTrue);
      expect(await AuthService.instance.refreshSession(), isTrue);
    }, () => client);

    expect(refreshCalls, 2);
    expect(AuthService.instance.token, 'token-2');
  });
}
