import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Altura da barra de navegação do Android (ou do indicador do iPhone).
///
/// Com o app em tela cheia (edge-to-edge) o Android zera `MediaQuery.padding`,
/// então `SafeArea` sozinho deixa o fim das listas embaixo dos botões do
/// sistema; `viewPadding` continua com a altura real.
double systemBottomInset(BuildContext context) {
  final mq = MediaQuery.of(context);
  return math.max(mq.viewPadding.bottom, mq.padding.bottom);
}

/// Padding de listas roláveis: [all] nas bordas e folga extra no fim, acima da
/// barra do sistema, para o último item nunca ficar coberto.
EdgeInsets scrollablePadding(BuildContext context, {double all = 16}) =>
    EdgeInsets.fromLTRB(all, all, all, all + 24 + systemBottomInset(context));
