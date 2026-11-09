package br.com.focodev.academia.dto;

import java.util.UUID;

public final class WorkoutTemplateDtos {

    private WorkoutTemplateDtos() {}

    public enum Modality { MUSCULACAO, CORRIDA, SPINNING, BIKE }

    public enum Level { INICIANTE, INTERMEDIARIO, AVANCADO }

    /** Ficha semanal (musculação, spinning, bike) ou treino outdoor de corrida. */
    public enum Kind { PROGRAM, CARDIO }

    public record TemplateSummary(
            String key,
            String title,
            Modality modality,
            Level level,
            Kind kind,
            String description,
            int daysPerWeek,
            int sessionMinutes
    ) {}

    /** O que foi criado ao começar um treino pronto. */
    public record StartTemplateResponse(
            Kind kind,
            UUID programId,
            UUID cardioWorkoutId
    ) {}
}
