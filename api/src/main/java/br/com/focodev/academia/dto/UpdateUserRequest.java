package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotNull;

public record UpdateUserRequest(
        @NotNull Boolean active
) {}
