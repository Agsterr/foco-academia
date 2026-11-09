import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/auth_service.dart';
import 'package:foco_academia_mobile/services/subscription_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStore implements StoreGateway {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <String>[];

  @override
  Stream<List<PurchaseDetails>> get purchases => controller.stream;

  @override
  Future<void> complete(PurchaseDetails purchase) async => completed.add(purchase.productID);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<StorePlan>> plans(List<String> ids) async => const [];

  @override
  Future<bool> buy(StorePlan plan) async => true;

  @override
  Future<void> restore() async {}
}

PurchaseDetails _purchase(PurchaseStatus status) => PurchaseDetails(
      productID: 'foco_premium_mensal',
      purchaseID: 'GPA.123',
      verificationData: PurchaseVerificationData(
        localVerificationData: '{}',
        serverVerificationData: 'token-da-compra',
        source: 'google_play',
      ),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = true;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.instance.token = 'token';
    store = _FakeStore();
  });

  Future<List<String>> deliver(PurchaseDetails purchase, MockClient client) async {
    final service = SubscriptionService.instance..store = store;
    final events = <String>[];
    final sub = service.events.listen(events.add);
    await http.runWithClient(() async {
      // Assina de novo a cada teste (o serviço é singleton).
      await service.debugListenForTests(store);
      store.controller.add([purchase]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }, () => client);
    await sub.cancel();
    return events;
  }

  test('compra confirmada pelo servidor libera o premium e é concluída no Google', () async {
    String? sentToken;
    final client = MockClient((request) async {
      sentToken = (jsonDecode(request.body) as Map)['purchaseToken'] as String?;
      return http.Response(
        jsonEncode({'premium': true, 'reason': 'SUBSCRIPTION', 'autoRenewing': true}),
        200,
      );
    });

    final events = await deliver(_purchase(PurchaseStatus.purchased), client);

    expect(sentToken, 'token-da-compra');
    expect(events, contains('ok'));
    expect(store.completed, ['foco_premium_mensal']);
    expect(SubscriptionService.instance.last?.subscribed, isTrue);
  });

  test('se o servidor não confirma, a compra NÃO é concluída (o Google entrega de novo depois)', () async {
    final client = MockClient((request) async =>
        http.Response(jsonEncode({'message': 'Não foi possível confirmar a compra agora.'}), 502));

    final events = await deliver(_purchase(PurchaseStatus.purchased), client);

    expect(store.completed, isEmpty);
    expect(events.single, contains('Não foi possível confirmar'));
  });

  test('pagamento pendente não é concluído; cancelado é', () async {
    final client = MockClient((request) async => http.Response('{}', 500));

    await deliver(_purchase(PurchaseStatus.pending), client);
    expect(store.completed, isEmpty);

    await deliver(_purchase(PurchaseStatus.canceled), client);
    expect(store.completed, ['foco_premium_mensal']);
  });

  test('resumo do cartão conforme o motivo do acesso', () {
    final trial = SubscriptionStatus(
      premium: true,
      reason: 'TRIAL',
      expiresAt: DateTime.now().add(const Duration(days: 5, hours: 2)),
    );
    expect(trial.summary, 'Teste grátis: faltam 6 dias');
    expect(const SubscriptionStatus(premium: true, reason: 'ACADEMY').summary, 'Incluído pela sua academia');
    expect(const SubscriptionStatus(premium: false, reason: 'NONE').summary, contains('Assine'));
  });
}
