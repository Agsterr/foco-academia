package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ExerciseRequest(
        @NotBlank @Size(max = 200) String name,
        @Size(max = 2000) String description,
        Integer sets,
        Integer reps,
        String duration,
        String videoUrl,
        String notes,
        int sortOrder
) {}
