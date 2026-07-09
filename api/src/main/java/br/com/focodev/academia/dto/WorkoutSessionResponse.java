package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.RatingLevel;
import br.com.focodev.academia.domain.WorkoutSession;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record WorkoutSessionResponse(
        UUID id,
        UUID workoutDayId,
        Instant startedAt,
        Instant completedAt,
        Long totalDurationSeconds,
        RatingLevel rating,
        String comment,
        List<SetLogResponse> setLogs
) {
    public static WorkoutSessionResponse from(WorkoutSession session) {
        return new WorkoutSessionResponse(
                session.getId(),
                session.getWorkoutDay().getId(),
                session.getStartedAt(),
                session.getCompletedAt(),
                session.getTotalDurationSeconds(),
                session.getRating(),
                session.getComment(),
                session.getSetLogs().stream().map(SetLogResponse::from).toList()
        );
    }
}
