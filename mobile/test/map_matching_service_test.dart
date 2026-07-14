import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:foco_academia_mobile/services/map_matching_service.dart';

void main() {
  test('matchToRoads parseia geometria GeoJSON do OSRM', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, contains('/match/v1/'));
      expect(request.url.queryParameters.containsKey('timestamps'), isTrue);
      return http.Response(
        '''
{
  "code": "Ok",
  "matchings": [{
    "confidence": 0.9,
    "geometry": {
      "type": "LineString",
      "coordinates": [
        [-46.63000, -23.55000],
        [-46.63010, -23.55010],
        [-46.63020, -23.55020]
      ]
    }
  }]
}
''',
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final svc = MapMatchingService(client: client);
    final t0 = DateTime.utc(2026, 1, 1, 12);
    final matched = await svc.matchToRoads(
      [
        const LatLng(-23.55000, -46.63000),
        const LatLng(-23.55015, -46.63015),
        const LatLng(-23.55030, -46.63030),
      ],
      recordedAt: [
        t0,
        t0.add(const Duration(seconds: 5)),
        t0.add(const Duration(seconds: 10)),
      ],
      accuraciesMeters: const [12, 12, 12],
    );

    expect(matched, isNotNull);
    expect(matched!.length, 3);
    expect(matched.first.latitude, closeTo(-23.55000, 0.00001));
    expect(matched.first.longitude, closeTo(-46.63000, 0.00001));
    expect(calls, greaterThanOrEqualTo(1));
    svc.dispose();
  });

  test('matchToRoads retorna null em erro HTTP', () async {
    final client = MockClient((request) async {
      return http.Response('nope', 500);
    });
    final svc = MapMatchingService(client: client);
    final matched = await svc.matchToRoads([
      const LatLng(-23.55, -46.63),
      const LatLng(-23.551, -46.631),
    ]);
    expect(matched, isNull);
    svc.dispose();
  });

  test('cleanTrail remove ida-e-volta de calçada/bolso', () {
    final svc = MapMatchingService(client: MockClient((_) async {
      return http.Response('{}', 500);
    }));
    final t0 = DateTime.utc(2026, 1, 1, 12);
    // Progresso norte + zig-zag leste/oeste (deriva).
    final raw = <LatLng>[
      const LatLng(-23.55000, -46.63000),
      const LatLng(-23.55004, -46.63000), // ~4 m N
      const LatLng(-23.55001, -46.63000), // volta quase ao início
      const LatLng(-23.55008, -46.63000), // progresso real
      const LatLng(-23.55012, -46.63000),
    ];
    final cleaned = svc.cleanTrail(
      raw,
      accuraciesMeters: List.filled(raw.length, 18),
      recordedAt: List.generate(
        raw.length,
        (i) => t0.add(Duration(seconds: i * 2)),
      ),
    );
    expect(cleaned.points.length, lessThan(raw.length));
    expect(cleaned.points.length, greaterThanOrEqualTo(2));
    // Não deve manter o ponto que voltou atrás.
    final lats = cleaned.points.map((p) => p.latitude).toList();
    expect(lats.contains(-23.55001), isFalse);
    svc.dispose();
  });

  test('cleanTrail remove cruzamentos em X de drift com tela apagada', () {
    final svc = MapMatchingService(client: MockClient((_) async {
      return http.Response('{}', 500);
    }));
    // Simula deriva: progresso + idas e voltas dentro de ~20 m.
    final raw = <LatLng>[
      const LatLng(-23.55000, -46.63000),
      const LatLng(-23.55008, -46.63000),
      const LatLng(-23.55008, -46.63012),
      const LatLng(-23.55008, -46.62988),
      const LatLng(-23.55016, -46.63000),
      const LatLng(-23.55010, -46.63010),
      const LatLng(-23.55024, -46.63000),
    ];
    final cleaned = svc.cleanTrail(
      raw,
      accuraciesMeters: List.filled(raw.length, 28.0),
    );
    expect(cleaned.points.length, lessThan(raw.length));
    expect(cleaned.points.length, greaterThanOrEqualTo(2));
    // Mantém progresso geral para o norte.
    expect(cleaned.points.last.latitude, lessThan(cleaned.points.first.latitude));
    svc.dispose();
  });
}
