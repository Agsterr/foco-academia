package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank @jakarta.validation.constraints.Email String email,
        @NotBlank String password,
        String deviceId,
        String deviceLabel
) {}
