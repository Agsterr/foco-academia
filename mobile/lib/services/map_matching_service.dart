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

  /// Encaixa a trilha nas ruas. Retorna null se falhar (UI usa trilha limpa).
  Future<List<LatLng>?> matchToRoads(
    List<LatLng> points, {
    List<double>? accuraciesMeters,
    List<DateTime>? recordedAt,
  }) async {
    if (points.length < 2) return null;

    final cleaned = cleanTrail(
      points,
      accuraciesMeters: accuraciesMeters,
      recordedAt: recordedAt,
    );
    if (cleaned.points.length < 2) return null;

    final sampled = _downsample(
      cleaned.points,
      times: cleaned.times,
      accuracies: cleaned.accuracies,
      maxPoints: 80,
    );

    final radii = _radiiFor(sampled.points.length, sampled.accuracies);
    final stamps = _timestampsFor(sampled.times);

    // Prefere perfil car para “seguir a rua” (evita pular calçada↔calçada).
    // Foot fica de fallback para trilhas/parques.
    final car = await _matchOsrm(
      baseUrl: carFallbackUrl,
      profile: 'driving',
      points: sampled.points,
      radiuses: radii,
      timestamps: stamps,
    );
    final foot = await _matchOsrm(
      baseUrl: footBaseUrl,
      profile: 'foot',
      points: sampled.points,
      radiuses: radii,
      timestamps: stamps,
    );

    return _pickBestMatch(
      raw: cleaned.points,
      candidates: [car, foot],
    );
  }

  /// Remove zig-zag de bolso / ida-e-volta na calçada antes do mapa.
  /// Usado também como fallback visual quando o OSRM falha.
  ({
    List<LatLng> points,
    List<DateTime>? times,
    List<double>? accuracies,
  }) cleanTrail(
    List<LatLng> points, {
    List<double>? accuraciesMeters,
    List<DateTime>? recordedAt,
  }) {
    if (points.length < 2) {
      return (points: points, times: recordedAt, accuracies: accuraciesMeters);
    }

    final kept = <LatLng>[points.first];
    final keptTimes = recordedAt != null ? <DateTime>[recordedAt.first] : null;
    final keptAcc =
        accuraciesMeters != null ? <double>[accuraciesMeters.first] : null;

    for (var i = 1; i < points.length; i++) {
      final cur = points[i];
      final prev = kept.last;
      final acc = accuraciesMeters == null
          ? 20.0
          : accuraciesMeters[math.min(i, accuraciesMeters.length - 1)];
      final dist = _haversineMeters(prev, cur);
      // Accuracy ruim (tela apagada) exige passo maior para não riscar espaguete.
      final minStep = math.max(3.5, math.min(acc * 0.40, 14.0));
      if (dist < minStep) continue;

      if (kept.length >= 2) {
        final before = kept[kept.length - 2];
        final prevSeg = _haversineMeters(before, prev);
        final noise = math.max(12.0, acc * 1.05);
        final backToBefore = _haversineMeters(before, cur);
        final turn = _bearingDelta(
          _bearing(before, prev),
          _bearing(prev, cur),
        );

        // Ida e volta na mesma calçada / deriva no bolso.
        if (prevSeg < noise &&
            dist < noise &&
            (turn >= 80 || backToBefore < noise * 0.80)) {
          continue;
        }

        // Ponto que desfaz progresso recente (volta atrás na trilha).
        if (kept.length >= 3) {
          final older = kept[kept.length - 3];
          if (_haversineMeters(older, cur) < noise * 0.75 && dist < noise) {
            continue;
          }
        }

        // Cruzamento em X típico de drift com tela apagada: volta perto de
        // qualquer ponto recente dentro do raio de erro.
        if (kept.length >= 4 && dist < noise) {
          var nearRecent = false;
          final from = math.max(0, kept.length - 6);
          for (var j = from; j < kept.length - 1; j++) {
            if (_haversineMeters(kept[j], cur) < noise * 0.55) {
              nearRecent = true;
              break;
            }
          }
          if (nearRecent && turn >= 60) continue;
        }
      }

      kept.add(cur);
      if (keptTimes != null && recordedAt != null) {
        keptTimes.add(recordedAt[math.min(i, recordedAt.length - 1)]);
      }
      if (keptAcc != null && accuraciesMeters != null) {
        keptAcc.add(
          accuraciesMeters[math.min(i, accuraciesMeters.length - 1)],
        );
      }
    }

    if (kept.length < 2 && points.length >= 2) {
      return (
        points: [points.first, points.last],
        times: recordedAt == null
            ? null
            : [recordedAt.first, recordedAt.last],
        accuracies: accuraciesMeters == null
            ? null
            : [accuraciesMeters.first, accuraciesMeters.last],
      );
    }

    return (points: kept, times: keptTimes, accuracies: keptAcc);
  }

  /// Snap de um único ponto (ponta ao vivo no mapa).
  Future<LatLng?> snapPoint(LatLng point, {double radiusMeters = 35}) async {
    final car = await _nearestOsrm(
      baseUrl: carFallbackUrl,
      profile: 'driving',
      point: point,
      radiusMeters: radiusMeters,
    );
    if (car != null) return car;
    return _nearestOsrm(
      baseUrl: footBaseUrl,
      profile: 'foot',
      point: point,
      radiusMeters: radiusMeters,
    );
  }

  Future<({List<LatLng> geometry, double confidence, double lengthMeters})?>
      _matchOsrm({
    required String baseUrl,
    required String profile,
    required List<LatLng> points,
    required String radiuses,
    String? timestamps,
  }) async {
    final coords = points
        .map((p) =>
            '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final ts = timestamps == null || timestamps.isEmpty
        ? ''
        : '&timestamps=$timestamps';
    final uri = Uri.parse(
      '$baseUrl/match/v1/$profile/$coords'
      '?geometries=geojson&overview=full&tidy=true&gaps=ignore'
      '&radiuses=$radiuses$ts',
    );
    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (json['code'] != 'Ok') return null;
      final geometry = _geometryFromMatchings(json);
      if (geometry == null || geometry.length < 2) return null;
      final confidence = _avgConfidence(json);
      final length = _pathLength(geometry);
      return (geometry: geometry, confidence: confidence, lengthMeters: length);
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

  List<LatLng>? _pickBestMatch({
    required List<LatLng> raw,
    required List<
            ({List<LatLng> geometry, double confidence, double lengthMeters})?>
        candidates,
  }) {
    final rawLen = _pathLength(raw);
    ({List<LatLng> geometry, double confidence, double lengthMeters})? best;
    var bestScore = -1.0;

    for (final c in candidates) {
      if (c == null || c.geometry.length < 2) continue;
      // Penaliza rota que “passeia” demais vs trilha limpa (ida-e-volta).
      final inflate = rawLen <= 1
          ? 1.0
          : (c.lengthMeters / rawLen).clamp(0.5, 4.0);
      final score = c.confidence * 2.0 - (inflate - 1.0).abs();
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best?.geometry;
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

  double _avgConfidence(Map<String, dynamic> json) {
    final matchings = json['matchings'] as List<dynamic>?;
    if (matchings == null || matchings.isEmpty) return 0.5;
    var sum = 0.0;
    var n = 0;
    for (final m in matchings) {
      final c = (m as Map<String, dynamic>)['confidence'];
      if (c is num) {
        sum += c.toDouble();
        n++;
      }
    }
    return n == 0 ? 0.5 : sum / n;
  }

  ({
    List<LatLng> points,
    List<DateTime>? times,
    List<double>? accuracies,
  }) _downsample(
    List<LatLng> points, {
    List<DateTime>? times,
    List<double>? accuracies,
    required int maxPoints,
  }) {
    if (points.length <= maxPoints) {
      return (points: points, times: times, accuracies: accuracies);
    }
    final out = <LatLng>[points.first];
    final outT = times != null ? <DateTime>[times.first] : null;
    final outA = accuracies != null ? <double>[accuracies.first] : null;
    final step = (points.length - 1) / (maxPoints - 1);
    for (var i = 1; i < maxPoints - 1; i++) {
      final idx = (i * step).round().clamp(1, points.length - 2);
      out.add(points[idx]);
      if (outT != null && times != null) {
        outT.add(times[math.min(idx, times.length - 1)]);
      }
      if (outA != null && accuracies != null) {
        outA.add(accuracies[math.min(idx, accuracies.length - 1)]);
      }
    }
    out.add(points.last);
    if (outT != null && times != null) outT.add(times.last);
    if (outA != null && accuracies != null) outA.add(accuracies.last);
    return (points: out, times: outT, accuracies: outA);
  }

  String _radiiFor(int n, List<double>? accuracies) {
    // Raio maior no bolso (accuracy ruim) para achar a rua certa.
    const fallback = 30.0;
    if (accuracies == null || accuracies.isEmpty) {
      return List.filled(n, fallback.toStringAsFixed(0)).join(';');
    }
    final parts = <String>[];
    for (var i = 0; i < n; i++) {
      final idx = math.min(i, accuracies.length - 1);
      final r = (accuracies[idx] * 1.35).clamp(20.0, 60.0);
      parts.add(r.toStringAsFixed(0));
    }
    return parts.join(';');
  }

  String? _timestampsFor(List<DateTime>? times) {
    if (times == null || times.length < 2) return null;
    // OSRM exige timestamps Unix em ordem estritamente crescente.
    final secs = <int>[];
    var last = -1;
    for (final t in times) {
      var s = t.toUtc().millisecondsSinceEpoch ~/ 1000;
      if (s <= last) s = last + 1;
      secs.add(s);
      last = s;
    }
    return secs.join(';');
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

  double _pathLength(List<LatLng> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += _haversineMeters(pts[i - 1], pts[i]);
    }
    return total;
  }

  static double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final p1 = a.latitude * math.pi / 180.0;
    final p2 = b.latitude * math.pi / 180.0;
    final dPhi = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLam = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dLam / 2) * math.sin(dLam / 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _bearing(LatLng a, LatLng b) {
    final phi1 = a.latitude * math.pi / 180.0;
    final phi2 = b.latitude * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final y = math.sin(dLng) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  static double _bearingDelta(double b1, double b2) {
    var d = (b2 - b1).abs() % 360.0;
    if (d > 180) d = 360 - d;
    return d;
  }

  void dispose() {
    _client.close();
  }
}
