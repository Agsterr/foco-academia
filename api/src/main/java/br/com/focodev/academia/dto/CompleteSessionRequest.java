package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.RatingLevel;
import jakarta.validation.constraints.Size;

public record CompleteSessionRequest(
        RatingLevel rating,
        @Size(max = 1000) String comment
) {}
