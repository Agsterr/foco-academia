package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.WorkoutDay;
import br.com.focodev.academia.domain.WeekDay;

import java.util.UUID;

public record WorkoutDayResponse(
        UUID id,
        WeekDay weekDay,
        String muscleGroup,
        String notes,
        boolean restDay,
        int sortOrder,
        java.util.List<ExerciseResponse> exercises,
        UUID activeSessionId,
        boolean completedThisWeek
) {
    public static WorkoutDayResponse from(WorkoutDay day) {
        return from(day, null, false);
    }

    public static WorkoutDayResponse from(WorkoutDay day, UUID activeSessionId, boolean completedThisWeek) {
        return new WorkoutDayResponse(
                day.getId(),
                day.getWeekDay(),
                day.getMuscleGroup(),
                day.getNotes(),
                day.isRestDay(),
                day.getSortOrder(),
                day.getExercises().stream().map(ExerciseResponse::from).toList(),
                activeSessionId,
                completedThisWeek
        );
    }
}
