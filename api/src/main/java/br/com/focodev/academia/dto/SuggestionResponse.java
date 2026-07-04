package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Suggestion;
import br.com.focodev.academia.domain.SuggestionStatus;

import java.time.Instant;
import java.util.UUID;

public record SuggestionResponse(
        UUID id,
        String message,
        String category,
        SuggestionStatus status,
        String response,
        Instant createdAt,
        Instant respondedAt,
        UserResponse student
) {
    public static SuggestionResponse from(Suggestion suggestion) {
        return new SuggestionResponse(
                suggestion.getId(),
                suggestion.getMessage(),
                suggestion.getCategory(),
                suggestion.getStatus(),
                suggestion.getResponse(),
                suggestion.getCreatedAt(),
                suggestion.getRespondedAt(),
                UserResponse.from(suggestion.getStudent())
        );
    }
}
