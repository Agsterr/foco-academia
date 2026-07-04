package br.com.focodev.academia.dto;

public record DashboardResponse(
        long totalStudents,
        long activeWorkouts,
        long pendingSuggestions
) {}
