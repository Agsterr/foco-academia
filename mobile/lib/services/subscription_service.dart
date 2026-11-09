import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'auth_service.dart';

/// Estado da assinatura vindo da API (quem decide o acesso é o servidor, não o app).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.premium,
    required this.reason,
    this.expiresAt,
    this.autoRenewing = false,
    this.enforced = false,
    this.storeConfigured = false,
    this.productIds = const ['foco_premium_mensal', 'foco_premium_anual'],
  });

  final bool premium;

  /// ACADEMY, TRIAL, SUBSCRIPTION ou NONE.
  final String reason;
  final DateTime? expiresAt;
  final bool autoRenewing;
  final bool enforced;
  final bool storeConfigured;
  final List<String> productIds;

  bool get viaAcademy => reason == 'ACADEMY';
  bool get onTrial => reason == 'TRIAL';
  bool get subscribed => reason == 'SUBSCRIPTION';

  int? get daysLeft {
    final end = expiresAt;
    if (end == null) return null;
    final hours = end.difference(DateTime.now()).inHours;
    return hours <= 0 ? 0 : (hours / 24).ceil();
  }

  /// Linha curta para o cartão da tela inicial.
  String get summary {
    if (viaAcademy) return 'Incluído pela sua academia';
    if (onTrial) {
      final d = daysLeft ?? 0;
      return d <= 1 ? 'Teste grátis termina hoje' : 'Teste grátis: faltam $d dias';
    }
    if (subscribed) return autoRenewing ? 'Assinatura ativa' : 'Ativo até ${_date(expiresAt)}';
    return 'Assine para liberar treinos prontos e montar treinos';
  }

  static String _date(DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) => SubscriptionStatus(
        premium: json['premium'] as bool? ?? false,
        reason: json['reason'] as String? ?? 'NONE',
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
        autoRenewing: json['autoRenewing'] as bool? ?? false,
        enforced: json['enforced'] as bool? ?? false,
        storeConfigured: json['storeConfigured'] as bool? ?? false,
        productIds: (json['productIds'] as List<dynamic>?)?.cast<String>() ??
            const ['foco_premium_mensal', 'foco_premium_anual'],
      );
}

/// Plano à venda, com o preço que a Play Store mostra no país do usuário.
class StorePlan {
  const StorePlan({required this.id, required this.title, required this.price, this.details});

  final String id;
  final String title;
  final String price;
  final ProductDetails? details;

  bool get yearly => id.contains('anual');
}

/// Loja de compras (Google Play). Interface para os testes não dependerem do plugin.
abstract class StoreGateway {
  Future<bool> isAvailable();
  Future<List<StorePlan>> plans(List<String> ids);
  Future<bool> buy(StorePlan plan);
  Future<void> restore();
  Stream<List<PurchaseDetails>> get purchases;
  Future<void> complete(PurchaseDetails purchase);
}

class PlayStoreGateway implements StoreGateway {
  // Acesso preguiçoso: criar a instância já conecta ao Google Play.
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<List<StorePlan>> plans(List<String> ids) async {
    final response = await _iap.queryProductDetails(ids.toSet());
    return [
      for (final p in response.productDetails)
        StorePlan(id: p.id, title: p.title, price: p.price, details: p),
    ]..sort((a, b) => a.yearly ? 1 : (b.yearly ? -1 : 0));
  }

  @override
  Future<bool> buy(StorePlan plan) =>
      _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: plan.details!));

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  @override
  Future<void> complete(PurchaseDetails purchase) => _iap.completePurchase(purchase);
}

/// Assinatura Foco Premium: compra no Google Play, confirmação no servidor e estado de acesso.
class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  StoreGateway store = PlayStoreGateway();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Avisa a tela de assinatura sobre o resultado de uma compra.
  final _events = StreamController<String>.broadcast();
  Stream<String> get events => _events.stream;

  SubscriptionStatus? _last;
  SubscriptionStatus? get last => _last;

  Future<SubscriptionStatus> status() async {
    final data = await AuthService.instance.get('/api/student/subscription');
    return _last = SubscriptionStatus.fromJson(data);
  }

  /// Escuta compras da loja (inclusive as concluídas com o app fechado). Chamar ao abrir o app.
  void listen() {
    _purchaseSub ??= store.purchases.listen(_handlePurchases, onError: (_) {});
  }

  /// Só para testes: troca a loja e volta a escutar as compras dela.
  Future<void> debugListenForTests(StoreGateway fake) async {
    await _purchaseSub?.cancel();
    _purchaseSub = null;
    store = fake;
    listen();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      var finish = true;
      switch (p.status) {
        case PurchaseStatus.pending:
          finish = false;
          _events.add('Pagamento em processamento…');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            final data = await AuthService.instance.post('/api/student/subscription/google-play', {
              'productId': p.productID,
              'purchaseToken': p.verificationData.serverVerificationData,
            });
            _last = SubscriptionStatus.fromJson(data);
            _events.add('ok');
          } catch (e) {
            // Sem confirmar no servidor, não conclui: o Google entrega a compra de novo
            // na próxima abertura do app e tentamos outra vez (e não estorna antes de 3 dias).
            finish = false;
            _events.add(e.toString().replaceFirst('Exception: ', ''));
          }
        case PurchaseStatus.error:
          _events.add(p.error?.message ?? 'Não foi possível concluir a compra.');
        case PurchaseStatus.canceled:
          _events.add('Compra cancelada.');
      }
      if (finish && p.pendingCompletePurchase) {
        await store.complete(p);
      }
    }
  }
}
