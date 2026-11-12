import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/profile_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance
      ..token = 't'
      ..deviceId = 'd'
      ..userName = 'Mariana Irmã'
      ..role = 'ALUNO';
  });

  Future<T> withApi<T>(Future<T> Function() body, http.Response Function(http.Request) respond) =>
      http.runWithClient(body, () => MockClient((r) async => respond(r)));

  test('conta criada pelo app (sem perfil) abre com perfil vazio, sem erro', () async {
    final profile = await withApi(
      () => ProfileService.instance.getProfile(),
      (_) => _json({'message': 'Perfil não encontrado'}, 400),
    );
    expect(profile.studentName, 'Mariana Irmã');
    expect(profile.heightCm, isNull);
    expect(profile.currentWeightKg, isNull);
    expect(profile.onboardingCompleted, isFalse);
  });

  test('perfil existente continua sendo lido normalmente', () async {
    final profile = await withApi(
      () => ProfileService.instance.getProfile(),
      (_) => _json({
        'studentId': 'u1',
        'studentName': 'Bruno',
        'heightCm': 178,
        'currentWeightKg': 78.5,
        'onboardingCompleted': true,
      }, 200),
    );
    expect(profile.heightCm, 178);
    expect(profile.currentWeightKg, 78.5);
    expect(profile.onboardingCompleted, isTrue);
  });

  test('outros erros do servidor não são escondidos', () async {
    await expectLater(
      withApi(() => ProfileService.instance.getProfile(), (_) => _json({'message': 'Erro interno'}, 500)),
      throwsA(predicate((e) => e.toString().contains('Erro interno'))),
    );
  });
}
