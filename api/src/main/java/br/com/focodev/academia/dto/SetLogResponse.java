package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.SetLog;

import java.time.Instant;
import java.util.UUID;

public record SetLogResponse(
        UUID id,
        UUID exerciseId,
        int setNumber,
        Instant completedAt,
        Long elapsedMs
) {
    public static SetLogResponse from(SetLog log) {
        return new SetLogResponse(
                log.getId(),
                log.getExercise().getId(),
                log.getSetNumber(),
                log.getCompletedAt(),
                log.getElapsedMs()
        );
    }
}
