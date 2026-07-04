package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SuggestionResponseRequest(
        @NotBlank @Size(min = 1, max = 2000) String response
) {}
