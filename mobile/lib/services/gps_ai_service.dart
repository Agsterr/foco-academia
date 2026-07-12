import 'auth_service.dart';

class GpsAiFinding {
  const GpsAiFinding({
    required this.code,
    required this.severity,
    required this.title,
    this.detail,
    this.sequenceFrom,
    this.sequenceTo,
  });

  final String code;
  final String severity;
  final String title;
  final String? detail;
  final int? sequenceFrom;
  final int? sequenceTo;

  factory GpsAiFinding.fromJson(Map<String, dynamic> json) {
    return GpsAiFinding(
      code: json['code'] as String? ?? '',
      severity: json['severity'] as String? ?? 'INFO',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String?,
      sequenceFrom: (json['sequenceFrom'] as num?)?.toInt(),
      sequenceTo: (json['sequenceTo'] as num?)?.toInt(),
    );
  }
}

class GpsAiSegmentSuggestion {
  const GpsAiSegmentSuggestion({
    required this.sequenceFrom,
    required this.sequenceTo,
    required this.action,
    required this.reason,
  });

  final int sequenceFrom;
  final int sequenceTo;
  final String action;
  final String reason;

  factory GpsAiSegmentSuggestion.fromJson(Map<String, dynamic> json) {
    return GpsAiSegmentSuggestion(
      sequenceFrom: (json['sequenceFrom'] as num?)?.toInt() ?? 0,
      sequenceTo: (json['sequenceTo'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class SessionAiInsights {
  const SessionAiInsights({
    required this.sessionId,
    required this.overallRiskScore,
    required this.summary,
    required this.findings,
    required this.segmentSuggestions,
    required this.suspiciousActivity,
    this.trendLabel,
    this.avgPaceSecPerKm,
    this.avgSpeedKmh,
  });

  final String sessionId;
  final double overallRiskScore;
  final String summary;
  final List<GpsAiFinding> findings;
  final List<GpsAiSegmentSuggestion> segmentSuggestions;
  final bool suspiciousActivity;
  final String? trendLabel;
  final double? avgPaceSecPerKm;
  final double? avgSpeedKmh;

  factory SessionAiInsights.fromJson(Map<String, dynamic> json) {
    final perf = json['performance'] as Map<String, dynamic>?;
    final findingsRaw = json['findings'] as List<dynamic>? ?? const [];
    final suggestionsRaw =
        json['segmentSuggestions'] as List<dynamic>? ?? const [];
    return SessionAiInsights(
      sessionId: json['sessionId'] as String? ?? '',
      overallRiskScore: (json['overallRiskScore'] as num?)?.toDouble() ?? 0,
      summary: json['summary'] as String? ?? '',
      findings: findingsRaw
          .map((e) => GpsAiFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      segmentSuggestions: suggestionsRaw
          .map((e) =>
              GpsAiSegmentSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      suspiciousActivity: json['suspiciousActivity'] as bool? ?? false,
      trendLabel: perf?['trendLabel'] as String?,
      avgPaceSecPerKm: (perf?['avgPaceSecPerKm'] as num?)?.toDouble(),
      avgSpeedKmh: (perf?['avgSpeedKmh'] as num?)?.toDouble(),
    );
  }
}

class AthleteRecommendations {
  const AthleteRecommendations({
    required this.evolutionSummary,
    required this.recommendations,
    required this.warnings,
    this.predictedNextKmPaceSecPerKm,
  });

  final String evolutionSummary;
  final List<String> recommendations;
  final List<String> warnings;
  final double? predictedNextKmPaceSecPerKm;

  factory AthleteRecommendations.fromJson(Map<String, dynamic> json) {
    return AthleteRecommendations(
      evolutionSummary: json['evolutionSummary'] as String? ?? '',
      predictedNextKmPaceSecPerKm:
          (json['predictedNextKmPaceSecPerKm'] as num?)?.toDouble(),
      recommendations: (json['recommendations'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class GpsAiService {
  GpsAiService._();
  static final instance = GpsAiService._();

  Future<SessionAiInsights> sessionInsights(String sessionId) async {
    final data = await AuthService.instance
        .get('/api/student/cardio-sessions/$sessionId/ai-insights');
    return SessionAiInsights.fromJson(data);
  }

  Future<AthleteRecommendations> recommendations() async {
    final data =
        await AuthService.instance.get('/api/student/ai/recommendations');
    return AthleteRecommendations.fromJson(data);
  }
}
