package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.MediaType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ExerciseRequest(
        @NotBlank @Size(max = 200) String name,
        @Size(max = 2000) String description,
        Integer sets,
        Integer reps,
        String duration,
        String videoUrl,
        MediaType mediaType,
        @Size(max = 1000) String variationNotes,
        String notes,
        int sortOrder
) {}
