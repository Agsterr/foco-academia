package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.WorkoutStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record CreateWorkoutRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 2000) String description,
        @NotNull UUID studentId,
        LocalDate scheduledDate,
        WorkoutStatus status,
        @Valid List<ExerciseRequest> exercises
) {}
