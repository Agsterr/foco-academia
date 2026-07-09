package br.com.focodev.academia.dto;

public record SessionCompleteResponse(
        WorkoutSessionResponse session,
        StudentStatsResponse stats,
        String message
) {}
