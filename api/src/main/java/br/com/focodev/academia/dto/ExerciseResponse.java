package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Exercise;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record ExerciseResponse(
        UUID id,
        String name,
        String description,
        Integer sets,
        Integer reps,
        String duration,
        String videoUrl,
        String notes,
        int sortOrder
) {
    public static ExerciseResponse from(Exercise exercise) {
        return new ExerciseResponse(
                exercise.getId(),
                exercise.getName(),
                exercise.getDescription(),
                exercise.getSets(),
                exercise.getReps(),
                exercise.getDuration(),
                exercise.getVideoUrl(),
                exercise.getNotes(),
                exercise.getSortOrder()
        );
    }
}
