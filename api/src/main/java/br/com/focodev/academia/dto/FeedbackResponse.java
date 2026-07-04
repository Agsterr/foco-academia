package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.RatingLevel;
import br.com.focodev.academia.domain.WorkoutFeedback;

import java.time.Instant;
import java.util.UUID;

public record FeedbackResponse(
        UUID id,
        UUID workoutId,
        RatingLevel rating,
        boolean completed,
        String comment,
        Instant createdAt,
        UserResponse student
) {
    public static FeedbackResponse from(WorkoutFeedback feedback) {
        return new FeedbackResponse(
                feedback.getId(),
                feedback.getWorkout().getId(),
                feedback.getRating(),
                feedback.isCompleted(),
                feedback.getComment(),
                feedback.getCreatedAt(),
                UserResponse.from(feedback.getStudent())
        );
    }
}
