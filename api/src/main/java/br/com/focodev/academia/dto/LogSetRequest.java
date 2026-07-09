package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record LogSetRequest(
        @NotNull UUID exerciseId,
        int setNumber
) {}
