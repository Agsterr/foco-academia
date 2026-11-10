import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Peças visuais do app: ícones em selos coloridos, botões e cartões com gradiente.

/// Nas capturas da Play Store o renderizador de teste não desfoca sombras (ficariam como faixas
/// sólidas), então elas são desligadas com `--dart-define=PLAY_SCREENSHOTS=true`.
const _flatForScreenshots = bool.fromEnvironment('PLAY_SCREENSHOTS');

/// Brilho colorido embaixo de selos, botões e cartões.
List<BoxShadow>? glowShadow(Color color, {double alpha = 0.4, double blur = 18, double dy = 8}) {
  if (_flatForScreenshots) return null;
  return [BoxShadow(color: color.withValues(alpha: alpha), blurRadius: blur, offset: Offset(0, dy))];
}

/// Ícone branco num quadrado arredondado com gradiente e brilho.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.gradient, this.size = 48, this.glow = true});

  final IconData icon;
  final Gradient gradient;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: glow ? glowShadow(AppTheme.glowOf(gradient), alpha: 0.45, blur: size * 0.4, dy: size * 0.12) : null,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Botão principal com gradiente (ações como entrar, aceitar, assinar).
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppTheme.brandGradient,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Opacity(
      opacity: enabled || loading ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: glowShadow(AppTheme.glowOf(gradient), blur: 22, dy: 10),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cartão com gradiente forte e bolhas de luz (destaques: resumo do dia, convite, premium).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.child,
    this.gradient = AppTheme.brandGradient,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: glowShadow(AppTheme.glowOf(gradient), alpha: 0.35, blur: 30, dy: 14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                const Positioned(top: -50, right: -30, child: _Bubble(size: 160, alpha: 0.16)),
                const Positioned(bottom: -60, left: -40, child: _Bubble(size: 140, alpha: 0.10)),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
    );
  }
}

/// Linha de menu: selo colorido, título, descrição e seta.
class VibrantTile extends StatelessWidget {
  const VibrantTile({
    super.key,
    required this.icon,
    required this.gradient,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.leading,
  });

  final IconData icon;
  final Gradient gradient;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Substitui o selo (ex.: um indicador de carregamento).
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              leading ?? IconBadge(icon: icon, gradient: gradient, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              trailing ?? Icon(Icons.chevron_right_rounded, color: AppTheme.glowOf(gradient)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Atalho grande para a grade da tela inicial.
class FeatureTile extends StatelessWidget {
  const FeatureTile({
    super.key,
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final glow = AppTheme.glowOf(gradient);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [glow.withValues(alpha: 0.22), AppTheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: glow.withValues(alpha: 0.35)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon: icon, gradient: gradient, size: 44),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de seção com um traço colorido.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.gradient = AppTheme.brandGradient});

  final String title;
  final Widget? trailing;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Fundo com manchas de cor desfocadas (telas de entrada).
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppTheme.background)),
        const Positioned(top: -140, right: -100, child: _Glow(color: AppTheme.violet, size: 360)),
        const Positioned(top: 160, left: -160, child: _Glow(color: AppTheme.pink, size: 320)),
        const Positioned(bottom: -160, right: -80, child: _Glow(color: AppTheme.orange, size: 300)),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.38), color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Cores de cada modalidade de treino.
Gradient gradientForModality(String? modality) {
  switch ((modality ?? '').toUpperCase()) {
    case 'MUSCULACAO':
      return AppTheme.fireGradient;
    case 'CORRIDA':
      return AppTheme.freshGradient;
    case 'SPINNING':
      return AppTheme.berryGradient;
    case 'BIKE':
      return AppTheme.oceanGradient;
    default:
      return AppTheme.brandGradient;
  }
}

IconData iconForModality(String? modality) {
  switch ((modality ?? '').toUpperCase()) {
    case 'MUSCULACAO':
      return Icons.fitness_center_rounded;
    case 'CORRIDA':
      return Icons.directions_run_rounded;
    case 'SPINNING':
      return Icons.pedal_bike_rounded;
    case 'BIKE':
      return Icons.directions_bike_rounded;
    default:
      return Icons.bolt_rounded;
  }
}
