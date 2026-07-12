package br.com.focodev.academia.dto;

import java.util.List;
import java.util.Map;
import java.util.UUID;

public final class GpsAnalyticsDtos {

    private GpsAnalyticsDtos() {}

    public record InstructorGpsAnalyticsResponse(
            long completedSessions,
            Double avgGpsQualityScore,
            Map<String, Long> qualityLabelCounts,
            Map<String, Long> filterReasonCounts,
            Map<String, Long> diagnosticEventCounts,
            Map<String, Long> algorithmVersionCounts
    ) {}

    public record GpsDiagnosticResponse(
            UUID id,
            String eventType,
            String recordedAt,
            String message,
            Double latitude,
            Double longitude,
            Double accuracy
    ) {}

    public record GpsDiagnosticRequest(
            String eventType,
            String timestamp,
            String message,
            Double latitude,
            Double longitude,
            Double accuracy,
            String clientSessionId,
            UUID sessionId
    ) {}

    public record AddGpsDiagnosticsRequest(
            List<GpsDiagnosticRequest> events
    ) {}

    public record GpsConfigResponse(
            boolean kalmanEnabled,
            boolean jumpDetectionEnabled,
            boolean confidenceEnabled,
            boolean adaptiveSamplingEnabled,
            boolean autoPauseEnabled,
            double minAccuracy,
            double maxSpeed,
            double minDistance
    ) {
        public static GpsConfigResponse defaults() {
            return new GpsConfigResponse(
                    true, true, true, false, false,
                    45, 40, 2.5
            );
        }
    }
}
