package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Workout;
import br.com.focodev.academia.domain.WorkoutStatus;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record WorkoutResponse(
        UUID id,
        String title,
        String description,
        WorkoutStatus status,
        LocalDate scheduledDate,
        Instant createdAt,
        UserResponse student,
        List<ExerciseResponse> exercises
) {
    public static WorkoutResponse from(Workout workout) {
        return new WorkoutResponse(
                workout.getId(),
                workout.getTitle(),
                workout.getDescription(),
                workout.getStatus(),
                workout.getScheduledDate(),
                workout.getCreatedAt(),
                UserResponse.from(workout.getStudent()),
                workout.getExercises().stream().map(ExerciseResponse::from).toList()
        );
    }
}
