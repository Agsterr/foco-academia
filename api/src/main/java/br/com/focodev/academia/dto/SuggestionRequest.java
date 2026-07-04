package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SuggestionRequest(
        @NotBlank @Size(min = 3, max = 2000) String message,
        @Size(max = 100) String category
) {}
