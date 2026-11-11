import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Desenho animado de um exercício: um boneco de lado que passa pelas poses do movimento.
///
/// Cada pose é descrita por ângulos das articulações (cinemática direta), então os membros
/// nunca esticam nem encolhem ao animar. Convenção dos ângulos, em graus:
/// 0 = apontando para baixo, 90 = para a frente (direita), 180 = para cima, 270 (ou -90) = para trás.
/// O boneco olha sempre para a direita.
class FigurePose {
  const FigurePose({
    this.torso = 180,
    this.arm = const [0, 0],
    this.arm2 = const [0, 0],
    this.leg = const [0, 0],
    this.leg2 = const [0, 0],
    this.lift = 0,
  });

  /// Direção do quadril até o pescoço (180 = em pé).
  final double torso;

  /// [braço, antebraço] do lado de perto.
  final List<double> arm;

  /// [braço, antebraço] do lado de longe (desenhado mais apagado).
  final List<double> arm2;

  /// [coxa, canela] da perna de perto.
  final List<double> leg;

  /// [coxa, canela] da perna de longe.
  final List<double> leg2;

  /// Altura do salto (fração da área de desenho); 0 = com o pé no chão.
  final double lift;

  static FigurePose lerp(FigurePose a, FigurePose b, double t) {
    double l(double x, double y) => x + (y - x) * t;
    List<double> ll(List<double> x, List<double> y) => [l(x[0], y[0]), l(x[1], y[1])];
    return FigurePose(
      torso: l(a.torso, b.torso),
      arm: ll(a.arm, b.arm),
      arm2: ll(a.arm2, b.arm2),
      leg: ll(a.leg, b.leg),
      leg2: ll(a.leg2, b.leg2),
      lift: l(a.lift, b.lift),
    );
  }
}

/// Posições (já em pixels lógicos, relativas a uma área de 1x1) das articulações de uma pose.
class FigureJoints {
  FigureJoints({
    required this.hip,
    required this.neck,
    required this.head,
    required this.elbow,
    required this.hand,
    required this.elbow2,
    required this.hand2,
    required this.knee,
    required this.foot,
    required this.knee2,
    required this.foot2,
  });

  final Offset hip, neck, head, elbow, hand, elbow2, hand2, knee, foot, knee2, foot2;

  static const double torsoLen = 0.26;
  static const double upperArm = 0.13;
  static const double foreArm = 0.12;
  static const double thigh = 0.17;
  static const double shin = 0.17;
  static const double headDist = 0.075;
  static const double headRadius = 0.05;

  static Offset _dir(double deg) {
    final r = deg * math.pi / 180;
    return Offset(math.sin(r), math.cos(r));
  }

  /// Articulações com o quadril na origem, sem posicionamento no chão.
  factory FigureJoints.fromPose(FigurePose p) {
    const hip = Offset.zero;
    final neck = hip + _dir(p.torso) * torsoLen;
    final head = neck + _dir(p.torso) * headDist;
    final elbow = neck + _dir(p.arm[0]) * upperArm;
    final hand = elbow + _dir(p.arm[1]) * foreArm;
    final elbow2 = neck + _dir(p.arm2[0]) * upperArm;
    final hand2 = elbow2 + _dir(p.arm2[1]) * foreArm;
    final knee = hip + _dir(p.leg[0]) * thigh;
    final foot = knee + _dir(p.leg[1]) * shin;
    final knee2 = hip + _dir(p.leg2[0]) * thigh;
    final foot2 = knee2 + _dir(p.leg2[1]) * shin;
    return FigureJoints(
      hip: hip,
      neck: neck,
      head: head,
      elbow: elbow,
      hand: hand,
      elbow2: elbow2,
      hand2: hand2,
      knee: knee,
      foot: foot,
      knee2: knee2,
      foot2: foot2,
    );
  }

  List<Offset> get points => [hip, neck, head, elbow, hand, elbow2, hand2, knee, foot, knee2, foot2];

  /// Menor e maior x, e maior y (ponto mais baixo, contando a cabeça) do corpo.
  (double minX, double maxX, double maxY) get bounds {
    var minX = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    maxY = math.max(maxY, head.dy + headRadius);
    minX = math.min(minX, head.dx - headRadius);
    maxX = math.max(maxX, head.dx + headRadius);
    return (minX, maxX, maxY);
  }
}

/// Um exercício desenhado: sequência de poses que se repete em ciclo (a última volta para a primeira).
class FigureAnimation {
  const FigureAnimation(this.poses, {this.wall = false, this.cycleMs = 1600});

  final List<FigurePose> poses;

  /// Desenha uma parede atrás do boneco (cadeirinha).
  final bool wall;

  /// Duração de um ciclo completo.
  final int cycleMs;

  /// Pose no instante [t] (0..1) do ciclo, com suavização entre os quadros.
  FigurePose at(double t) {
    final n = poses.length;
    if (n == 1) return poses.first;
    final scaled = (t % 1.0) * n;
    final i = scaled.floor() % n;
    final local = Curves.easeInOutCubic.transform(scaled - scaled.floor());
    return FigurePose.lerp(poses[i], poses[(i + 1) % n], local);
  }

  /// Centro horizontal fixo do ciclo, para o boneco não deslizar ao animar.
  double get centerX {
    var lo = double.infinity, hi = -double.infinity;
    for (final p in poses) {
      final b = FigureJoints.fromPose(p).bounds;
      lo = math.min(lo, b.$1);
      hi = math.max(hi, b.$2);
    }
    return (lo + hi) / 2;
  }
}

/// Widget que toca o desenho em loop. Com [animate] falso mostra só a primeira pose.
class ExerciseFigure extends StatefulWidget {
  const ExerciseFigure({
    super.key,
    required this.animation,
    this.color = AppTheme.accent,
    this.size = 220,
    this.animate = true,
    this.showFloor = true,
  });

  final FigureAnimation animation;
  final Color color;
  final double size;
  final bool animate;
  final bool showFloor;

  @override
  State<ExerciseFigure> createState() => _ExerciseFigureState();
}

class _ExerciseFigureState extends State<ExerciseFigure> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: widget.animation.cycleMs));
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(ExerciseFigure old) {
    super.didUpdateWidget(old);
    _controller.duration = Duration(milliseconds: widget.animation.cycleMs);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _FigurePainter(
              animation: widget.animation,
              t: widget.animate ? _controller.value : 0,
              color: widget.color,
              showFloor: widget.showFloor,
            ),
          ),
        ),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.animation, required this.t, required this.color, required this.showFloor});

  final FigureAnimation animation;
  final double t;
  final Color color;
  final bool showFloor;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final pose = animation.at(t);
    final j = FigureJoints.fromPose(pose);
    final floorY = s * 0.88;
    final cx = animation.centerX;
    final maxY = j.bounds.$3;
    // Reduz o boneco para caber com os braços esticados para cima ou em salto.
    const k = 0.8;

    // Posiciona: centraliza em x e apoia o ponto mais baixo no chão (menos o salto).
    Offset place(Offset p) => Offset(
          s * 0.5 + (p.dx - cx) * s * k,
          floorY + (p.dy - maxY - pose.lift) * s * k,
        );

    // Chão e brilho de fundo.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(s * 0.5, s * 0.55), radius: s * 0.5));
    canvas.drawCircle(Offset(s * 0.5, s * 0.55), s * 0.5, glow);

    if (showFloor) {
      final mat = RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.06, floorY + s * 0.012, s * 0.88, s * 0.035),
        Radius.circular(s * 0.02),
      );
      canvas.drawRRect(mat, Paint()..color = color.withValues(alpha: 0.35));
      // Sombra do salto: encolhe quando o boneco sobe.
      if (pose.lift > 0) {
        final k = (1 - pose.lift * 3).clamp(0.4, 1.0);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(s * 0.5, floorY + s * 0.03), width: s * 0.3 * k, height: s * 0.03),
          Paint()..color = Colors.black.withValues(alpha: 0.35),
        );
      }
    }

    if (animation.wall) {
      final minX = FigureJoints.fromPose(animation.poses.first).bounds.$1;
      final wallX = s * 0.5 + (minX - cx) * s * k - s * 0.03;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(wallX - s * 0.025, s * 0.1, s * 0.025, floorY - s * 0.1), Radius.circular(s * 0.01)),
        Paint()..color = AppTheme.outline,
      );
    }

    final stroke = s * 0.045;
    final far = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = stroke * 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final near = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final body = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke * 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void limb(Paint paint, Offset a, Offset b, Offset c) {
      canvas.drawPath(
        Path()
          ..moveTo(place(a).dx, place(a).dy)
          ..lineTo(place(b).dx, place(b).dy)
          ..lineTo(place(c).dx, place(c).dy),
        paint,
      );
    }

    // Lado de longe primeiro, depois o tronco e por cima o lado de perto.
    limb(far, j.neck, j.elbow2, j.hand2);
    limb(far, j.hip, j.knee2, j.foot2);
    canvas.drawLine(place(j.hip), place(j.neck), body);
    limb(near, j.hip, j.knee, j.foot);
    limb(near, j.neck, j.elbow, j.hand);

    // Cabeça com contorno.
    final headC = place(j.head);
    final r = FigureJoints.headRadius * s * k;
    canvas.drawCircle(headC, r, Paint()..color = Colors.white);
    canvas.drawCircle(
      headC,
      r,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014,
    );
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.t != t || old.color != color || old.animation != animation;
}
