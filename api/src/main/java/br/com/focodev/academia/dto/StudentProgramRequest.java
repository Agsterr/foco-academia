package br.com.focodev.academia.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/** Ficha montada pelo próprio aluno no app. */
public record StudentProgramRequest(
        @NotBlank @Size(max = 200) String title,
        @Size(max = 2000) String description,
        @Valid @NotNull @Size(min = 1, max = 7) List<WorkoutDayRequest> days
) {}
