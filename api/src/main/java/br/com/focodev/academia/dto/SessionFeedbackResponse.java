package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.RatingLevel;
import br.com.focodev.academia.domain.WeekDay;
import br.com.focodev.academia.domain.WorkoutSession;

import java.time.Instant;
import java.util.UUID;

public record SessionFeedbackResponse(
        UUID id,
        UserResponse student,
        String programTitle,
        WeekDay weekDay,
        String muscleGroup,
        RatingLevel rating,
        String comment,
        Long totalDurationSeconds,
        int setsCompleted,
        Instant completedAt
) {
    public static SessionFeedbackResponse from(WorkoutSession session) {
        return new SessionFeedbackResponse(
                session.getId(),
                UserResponse.from(session.getStudent()),
                session.getWorkoutDay().getProgram().getTitle(),
                session.getWorkoutDay().getWeekDay(),
                session.getWorkoutDay().getMuscleGroup(),
                session.getRating(),
                session.getComment(),
                session.getTotalDurationSeconds(),
                session.getSetLogs().size(),
                session.getCompletedAt()
        );
    }
}
