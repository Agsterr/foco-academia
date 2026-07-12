package br.com.focodev.academia.dto;

import java.util.List;
import java.util.UUID;

public final class GpsAiDtos {

    private GpsAiDtos() {}

    public record SessionAiInsightsResponse(
            UUID sessionId,
            double overallRiskScore,
            String summary,
            List<Finding> findings,
            List<SegmentSuggestion> segmentSuggestions,
            PerformanceSnapshot performance,
            boolean suspiciousActivity
    ) {}

    public record Finding(
            String code,
            String severity,
            String title,
            String detail,
            Integer sequenceFrom,
            Integer sequenceTo
    ) {}

    public record SegmentSuggestion(
            int sequenceFrom,
            int sequenceTo,
            String action,
            String reason
    ) {}

    public record PerformanceSnapshot(
            Double avgPaceSecPerKm,
            Double bestKmPaceSecPerKm,
            Double avgSpeedKmh,
            Double distanceMeters,
            Integer movingSec,
            String trendLabel
    ) {}

    public record AthleteRecommendationsResponse(
            String evolutionSummary,
            Double predictedNextKmPaceSecPerKm,
            List<String> recommendations,
            List<String> warnings
    ) {}
}
