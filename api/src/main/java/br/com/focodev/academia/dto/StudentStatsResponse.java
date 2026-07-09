package br.com.focodev.academia.dto;

import java.util.List;

public record StudentStatsResponse(
        int daysCompletedThisWeek,
        int totalWorkoutsCompleted,
        int currentStreak,
        List<String> completedWeekDays
) {}
