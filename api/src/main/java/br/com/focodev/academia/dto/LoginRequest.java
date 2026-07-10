package br.com.focodev.academia.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank @jakarta.validation.constraints.Email String email,
        @NotBlank String password,
        /** Código da academia (obrigatório para instrutor/aluno). */
        String academySlug,
        String deviceId,
        String deviceLabel
) {}
