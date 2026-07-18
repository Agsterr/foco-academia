package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.CardioType;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.util.List;
import java.util.UUID;

public final class CardioDtos {

    private CardioDtos() {}

    public record CardioIntervalDto(
            @NotBlank String phase,
            @Min(1) int durationSec
    ) {}

    public record CreateCardioWorkoutRequest(
            @NotNull UUID studentId,
            @NotBlank @Size(max = 200) String title,
            @NotNull CardioType type,
            @Valid List<CardioIntervalDto> intervals
    ) {}

    public record UpdateCardioWorkoutRequest(
            @NotBlank @Size(max = 200) String title,
            @NotNull CardioType type,
            @Valid List<CardioIntervalDto> intervals,
            Boolean active
    ) {}

    public record CardioWorkoutResponse(
            UUID id,
            UUID studentId,
            String studentName,
            String title,
            CardioType type,
            String intervalsJson,
            List<CardioIntervalDto> intervals,
            boolean active,
            String createdAt
    ) {}

    public record StartCardioSessionRequest(
            UUID workoutId,
            String clientSessionId
    ) {}

    public record RoutePointRequest(
            double latitude,
            double longitude,
            Double speedKmh,
            String recordedAt,
            int sequenceNum,
            Double accuracyMeters,
            Double heading,
            Double altitudeMeters,
            String provider,
            @com.fasterxml.jackson.annotation.JsonProperty("isFiltered") Boolean filtered,
            Double batteryLevel,
            Double verticalAccuracy,
            Double bearingAccuracy,
            Double speedAccuracy,
            String filterReason,
            Double confidenceScore
    ) {}

    public record AddRoutePointsRequest(
            @NotNull @Size(min = 1, max = 500) List<RoutePointRequest> points
    ) {}

    public record CompleteCardioSessionRequest(
            Double distanceMeters,
            Double avgSpeedKmh,
            Long elapsedMs,
            Long pausedMs,
            Integer pauseCount,
            Integer caloriesKcal,
            Double gpsQualityScore,
            String gpsQualityLabel,
            String gpsAlgorithmVersion,
            String filterVersion,
            String kalmanVersion,
            String distanceVersion,
            String caloriesVersion,
            String gpsConfigSnapshot,
            @Valid List<RoutePointRequest> points
    ) {}

    public record CardioSessionResponse(
            UUID id,
            UUID workoutId,
            String workoutTitle,
            UUID studentId,
            String studentName,
            String startedAt,
            String completedAt,
            Double distanceMeters,
            Double avgSpeedKmh,
            Long elapsedMs,
            Long pausedMs,
            Integer pauseCount,
            Integer caloriesKcal,
            Double gpsQualityScore,
            String gpsQualityLabel,
            String gpsAlgorithmVersion,
            String filterVersion,
            String kalmanVersion,
            String distanceVersion,
            String caloriesVersion,
            List<RoutePointResponse> routePoints
    ) {}

    public record RoutePointResponse(
            double latitude,
            double longitude,
            Double speedKmh,
            String recordedAt,
            int sequenceNum,
            Double accuracyMeters,
            Double heading,
            Double altitudeMeters,
            String provider,
            @com.fasterxml.jackson.annotation.JsonProperty("isFiltered") Boolean filtered,
            Double batteryLevel,
            Double verticalAccuracy,
            Double bearingAccuracy,
            Double speedAccuracy,
            String filterReason,
            Double confidenceScore
    ) {}

    public record InstructorCardioStatsResponse(
            long sessionsThisWeek,
            double totalKmThisWeek,
            double avgSpeedKmh,
            List<CardioSessionResponse> recentSessions,
            List<StudentProfileDtos.WeightCheckScheduleResponse> overdueWeightChecks
    ) {}

    public record SyncMeasurementDto(
            String clientId,
            Double weightKg,
            Double waistCm,
            String recordedAt
    ) {}

    public record SyncCardioSessionDto(
            String clientSessionId,
            UUID workoutId,
            String startedAt,
            String completedAt,
            Double distanceMeters,
            Double avgSpeedKmh,
            Long elapsedMs,
            Long pausedMs,
            Integer pauseCount,
            Integer caloriesKcal,
            Double gpsQualityScore,
            String gpsQualityLabel,
            String gpsAlgorithmVersion,
            String filterVersion,
            String kalmanVersion,
            String distanceVersion,
            String caloriesVersion,
            String gpsConfigSnapshot,
            List<RoutePointRequest> points
    ) {}

    public record StudentSyncRequest(
            List<SyncMeasurementDto> measurements,
            List<SyncCardioSessionDto> cardioSessions,
            List<br.com.focodev.academia.dto.GpsAnalyticsDtos.GpsDiagnosticRequest> diagnostics
    ) {}

    public record StudentSyncResponse(
            int measurementsSynced,
            int sessionsSynced
    ) {}
}
