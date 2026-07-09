package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.WeekDay;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record WorkoutDayRequest(
        @NotNull WeekDay weekDay,
        @Size(max = 200) String muscleGroup,
        @Size(max = 1000) String notes,
        boolean restDay,
        int sortOrder,
        @Valid List<ExerciseRequest> exercises
) {}
