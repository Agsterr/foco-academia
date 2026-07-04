package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.RatingLevel;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record FeedbackRequest(
        @NotNull RatingLevel rating,
        boolean completed,
        @Size(max = 1000) String comment
) {}
