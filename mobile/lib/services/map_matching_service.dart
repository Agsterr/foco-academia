import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Map matching (snap-to-road) via OSRM — mesmo tipo de serviço usado
/// por apps de corrida para encaixar o GPS nas ruas do OpenStreetMap.
class MapMatchingService {
  MapMatchingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// OSRM foot (OpenStreetMap Deutschland) — perfil pedestre/corrida.
  static const footBaseUrl = 'https://routing.openstreetmap.de/routed-foot';

  /// Fallback car (demo OSRM) se o foot estiver indisponível.
  static const carFallbackUrl = 'https://router.project-osrm.org';

  static const _userAgent = 'FocoAcademia/1.0 (+https://focodev.com.br; outdoor-gps)';

  /// Encaixa a trilha nas ruas. Retorna null se falhar (UI usa GPS bruto).
  Future<List<LatLng>?> matchToRoads(
    List<LatLng> points, {
    List<double>? accuraciesMeters,
  }) async {
    if (points.length < 2) return null;

    final sampled = _downsample(points, maxPoints: 80);
    final radii = _radiiFor(sampled.length, accuraciesMeters);

    final foot = await _matchOsrm(
      baseUrl: footBaseUrl,
      profile: 'foot',
      points: sampled,
      radiuses: radii,
    );
    if (foot != null && foot.length >= 2) return foot;

    return _matchOsrm(
      baseUrl: carFallbackUrl,
      profile: 'driving',
      points: sampled,
      radiuses: radii,
    );
  }

  /// Snap de um único ponto (ponta ao vivo no mapa).
  Future<LatLng?> snapPoint(LatLng point, {double radiusMeters = 30}) async {
    final foot = await _nearestOsrm(
      baseUrl: footBaseUrl,
      profile: 'foot',
      point: point,
      radiusMeters: radiusMeters,
    );
    if (foot != null) return foot;
    return _nearestOsrm(
      baseUrl: carFallbackUrl,
      profile: 'driving',
      point: point,
      radiusMeters: radiusMeters,
    );
  }

  Future<List<LatLng>?> _matchOsrm({
    required String baseUrl,
    required String profile,
    required List<LatLng> points,
    required String radiuses,
  }) async {
    final coords = points
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final uri = Uri.parse(
      '$baseUrl/match/v1/$profile/$coords'
      '?geometries=geojson&overview=full&tidy=true&radiuses=$radiuses',
    );
    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;
      return _geometryFromMatchings(json);
    } catch (_) {
      return null;
    }
  }

  Future<LatLng?> _nearestOsrm({
    required String baseUrl,
    required String profile,
    required LatLng point,
    required double radiusMeters,
  }) async {
    final coord =
        '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';
    final uri = Uri.parse(
      '$baseUrl/nearest/v1/$profile/$coord'
      '?number=1&radiuses=${radiusMeters.toStringAsFixed(0)}',
    );
    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;
      final waypoints = json['waypoints'] as List<dynamic>?;
      if (waypoints == null || waypoints.isEmpty) return null;
      final loc = (waypoints.first as Map<String, dynamic>)['location'];
      if (loc is! List || loc.length < 2) return null;
      return LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  List<LatLng>? _geometryFromMatchings(Map<String, dynamic> json) {
    final matchings = json['matchings'] as List<dynamic>?;
    if (matchings == null || matchings.isEmpty) return null;

    final out = <LatLng>[];
    for (final m in matchings) {
      final geometry = (m as Map<String, dynamic>)['geometry'];
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'] as List<dynamic>?;
      if (coords == null) continue;
      for (final c in coords) {
        if (c is! List || c.length < 2) continue;
        out.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }
    return out.length >= 2 ? _dedupeClose(out) : null;
  }

  /// Reduz pontos para caber na URL do OSRM sem perder a forma da rota.
  List<LatLng> _downsample(List<LatLng> points, {required int maxPoints}) {
    if (points.length <= maxPoints) return points;
    final out = <LatLng>[points.first];
    final step = (points.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      out.add(points[(i * step).round()]);
    }
    out.add(points.last);
    return out;
  }

  String _radiiFor(int n, List<double>? accuracies) {
    // Raio de busca na malha viária (metros). GPS urbano ~15–35 m.
    const fallback = 25.0;
    if (accuracies == null || accuracies.isEmpty) {
      return List.filled(n, fallback.toStringAsFixed(0)).join(';');
    }
    final parts = <String>[];
    for (var i = 0; i < n; i++) {
      final idx = math.min(i, accuracies.length - 1);
      final r = accuracies[idx].clamp(15.0, 50.0);
      parts.add(r.toStringAsFixed(0));
    }
    return parts.join(';');
  }

  List<LatLng> _dedupeClose(List<LatLng> pts) {
    if (pts.length < 2) return pts;
    const minDeg = 0.000005; // ~0,5 m
    final out = <LatLng>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      final prev = out.last;
      final cur = pts[i];
      if ((prev.latitude - cur.latitude).abs() > minDeg ||
          (prev.longitude - cur.longitude).abs() > minDeg) {
        out.add(cur);
      }
    }
    return out;
  }

  void dispose() {
    _client.close();
  }
}
