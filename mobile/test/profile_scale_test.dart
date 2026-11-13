import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/core/theme/app_theme.dart';
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

Map<String, dynamic> _measurement(String id, double kg, String at, {String source = 'SCALE_BLE'}) =>
    {'id': id, 'weightKg': kg, 'recordedAt': at, 'source': source};

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

  /// Abre o perfil com uma tela alta (formulário inteiro visível) e um servidor simulado.
  Future<List<Map<String, dynamic>>> open(
    WidgetTester tester, {
    ScaleReader? scaleReader,
    Map<String, dynamic>? profile,
    Object? measurements = const <Object>[],
    bool measurementsFail = false,
    required Future<void> Function() body,
  }) async {
    tester.view.physicalSize = const Size(1080, 5400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final puts = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark(),
        home: scaleReader == null ? const ProfileScreen() : ProfileScreen(scaleReader: scaleReader),
      ));
      await settle(tester);
      await body();
    }, () => MockClient((r) async {
          if (r.method == 'GET' && r.url.path == '/api/student/profile') {
            return profile == null ? _json({'message': 'Perfil não encontrado'}, 400) : _json(profile, 200);
          }
          if (r.method == 'GET' && r.url.path == '/api/student/measurements') {
            return measurementsFail ? http.Response('', 500) : _json(measurements!, 200);
          }
          if (r.method == 'PUT' && r.url.path == '/api/student/profile') {
            puts.add(jsonDecode(r.body) as Map<String, dynamic>);
            return _json({'studentId': 'u', 'studentName': 'M'}, 200);
          }
          return _json({}, 200);
        }));
    return puts;
  }

  String weightText(WidgetTester t) => t.widget<TextField>(find.byKey(const Key('weight-field'))).controller!.text;

  group('balança no campo de peso', () {
    testWidgets('o peso da balança vai direto para o campo e é salvo no perfil', (tester) async {
      final puts = await open(tester, scaleReader: (_) async => 81.74, body: () async {
        expect(weightText(tester), isEmpty);
        await tester.tap(find.byKey(const Key('weight-scale')));
        await settle(tester);
        expect(weightText(tester), '81,7');
        expect(find.textContaining('Peso da balança: 81,7 kg'), findsOneWidget);
        await tester.tap(find.text('Salvar'));
        await settle(tester);
      });
      expect(puts, hasLength(1));
      expect(puts.single['weightKg'], 81.7);
    });

    testWidgets('cancelar a balança não mexe no que estava digitado', (tester) async {
      await open(tester, scaleReader: (_) async => null, body: () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '78,5');
        await tester.tap(find.byKey(const Key('weight-scale')));
        await settle(tester);
        expect(weightText(tester), '78,5');
        expect(find.textContaining('Peso da balança'), findsNothing);
      });
    });

    testWidgets('o peso da balança limpa o aviso de peso inválido', (tester) async {
      await open(tester, scaleReader: (_) async => 64.0, body: () async {
        await tester.enterText(find.byKey(const Key('weight-field')), '5');
        await tester.tap(find.text('Salvar'));
        await settle(tester);
        expect(find.textContaining('Peso deve estar entre 20 e 500 kg'), findsOneWidget);
        await tester.tap(find.byKey(const Key('weight-scale')));
        await settle(tester);
        expect(find.textContaining('Peso deve estar entre 20 e 500 kg'), findsNothing);
        expect(weightText(tester), '64');
      });
    });

    testWidgets('mostra a dica da balança no campo de peso', (tester) async {
      await open(tester, body: () async {
        expect(find.textContaining('pegar da balança'), findsOneWidget);
        expect(find.byTooltip('Pegar o peso da balança Bluetooth'), findsOneWidget);
      });
    });
  });

  group('último peso medido no campo de peso', () {
    testWidgets('conta sem peso no perfil usa a medição mais recente (balança ou Evolução)', (tester) async {
      await open(tester, measurements: [
        _measurement('m2', 77.3, '2026-11-13T10:00:00Z'),
        _measurement('m1', 80.1, '2026-11-01T10:00:00Z', source: 'STUDENT'),
      ], body: () async {
        expect(weightText(tester), '77,3');
      });
    });

    testWidgets('quando o perfil já tem peso, ele vale (é atualizado a cada medição)', (tester) async {
      await open(
        tester,
        profile: {'studentId': 'u', 'studentName': 'M', 'currentWeightKg': 70.5},
        measurements: [_measurement('m1', 99.0, '2026-11-13T10:00:00Z')],
        body: () async {
          expect(weightText(tester), '70,5');
        },
      );
    });

    testWidgets('sem medições o campo fica vazio, sem erro', (tester) async {
      await open(tester, body: () async {
        expect(weightText(tester), isEmpty);
        expect(find.byKey(const Key('profile-error')), findsNothing);
      });
    });

    testWidgets('lista de pesos com erro não atrapalha a tela', (tester) async {
      await open(tester, measurementsFail: true, body: () async {
        expect(weightText(tester), isEmpty);
        expect(find.byKey(const Key('profile-error')), findsNothing);
      });
    });
  });
}
