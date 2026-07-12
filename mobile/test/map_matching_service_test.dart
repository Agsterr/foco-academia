import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:foco_academia_mobile/services/map_matching_service.dart';

void main() {
  test('matchToRoads parseia geometria GeoJSON do OSRM', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/match/v1/'));
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
    final matched = await svc.matchToRoads([
      const LatLng(-23.55000, -46.63000),
      const LatLng(-23.55015, -46.63015),
      const LatLng(-23.55030, -46.63030),
    ]);

    expect(matched, isNotNull);
    expect(matched!.length, 3);
    expect(matched.first.latitude, closeTo(-23.55000, 0.00001));
    expect(matched.first.longitude, closeTo(-46.63000, 0.00001));
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
}
