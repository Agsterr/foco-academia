import 'package:flutter/material.dart';

class RoutePointView {
  const RoutePointView({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Mapa simplificado da rota (mesmo conceito do SVG do aluno web).
class RouteMapView extends StatelessWidget {
  const RouteMapView({
    super.key,
    required this.points,
    this.height = 200,
    this.statusMessage,
  });

  final List<RoutePointView> points;
  final double height;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final waitingLabel = points.isEmpty
        ? (statusMessage ?? 'Aguardando GPS...')
        : points.length == 1
            ? (statusMessage ?? 'GPS ok — ande para traçar a rota')
            : null;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: waitingLabel != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  waitingLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                painter: _RoutePainter(points),
                child: const SizedBox.expand(),
              ),
            ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.points);

  final List<RoutePointView> points;

  @override
  void paint(Canvas canvas, Size size) {
    final lats = points.map((p) => p.latitude).toList();
    final lngs = points.map((p) => p.longitude).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    const pad = 0.0001;

    Offset toOffset(RoutePointView p) {
      final x = ((p.longitude - minLng + pad) / (maxLng - minLng + pad * 2)) * size.width;
      final y = size.height -
          ((p.latitude - minLat + pad) / (maxLat - minLat + pad * 2)) * size.height;
      return Offset(x, y);
    }

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = toOffset(points[i]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }

    final line = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, line);

    final start = toOffset(points.first);
    final end = toOffset(points.last);
    canvas.drawCircle(start, 5, Paint()..color = const Color(0xFF22C55E));
    canvas.drawCircle(end, 5, Paint()..color = const Color(0xFFEF4444));
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
