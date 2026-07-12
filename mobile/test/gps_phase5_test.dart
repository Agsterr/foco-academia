import 'package:flutter_test/flutter_test.dart';
import 'package:foco_academia_mobile/services/gps_ai_service.dart';

void main() {
  group('SessionAiInsights', () {
    test('fromJson mapeia findings e performance', () {
      final r = SessionAiInsights.fromJson({
        'sessionId': 'abc',
        'overallRiskScore': 42.5,
        'summary': 'Qualidade GPS comprometida',
        'suspiciousActivity': true,
        'findings': [
          {
            'code': 'GPS_JUMP',
            'severity': 'ERROR',
            'title': 'Salto GPS',
            'detail': '100 m',
            'sequenceFrom': 1,
            'sequenceTo': 2,
          },
        ],
        'segmentSuggestions': [
          {
            'sequenceFrom': 1,
            'sequenceTo': 2,
            'action': 'EXCLUDE_FROM_DISTANCE',
            'reason': 'Salto',
          },
        ],
        'performance': {
          'avgPaceSecPerKm': 360,
          'avgSpeedKmh': 10,
          'trendLabel': 'CORRIDA',
        },
      });
      expect(r.sessionId, 'abc');
      expect(r.overallRiskScore, 42.5);
      expect(r.suspiciousActivity, isTrue);
      expect(r.findings.single.code, 'GPS_JUMP');
      expect(r.segmentSuggestions.single.action, 'EXCLUDE_FROM_DISTANCE');
      expect(r.trendLabel, 'CORRIDA');
      expect(r.avgPaceSecPerKm, 360);
    });
  });

  group('AthleteRecommendations', () {
    test('fromJson', () {
      final r = AthleteRecommendations.fromJson({
        'evolutionSummary': 'Estável',
        'predictedNextKmPaceSecPerKm': 340,
        'recommendations': ['Aumente volume'],
        'warnings': ['GPS baixo'],
      });
      expect(r.evolutionSummary, 'Estável');
      expect(r.predictedNextKmPaceSecPerKm, 340);
      expect(r.recommendations, ['Aumente volume']);
      expect(r.warnings, ['GPS baixo']);
    });
  });
}
