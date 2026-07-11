package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.AppClientType;
import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank @jakarta.validation.constraints.Email String email,
        @NotBlank String password,
        /** Código da academia (obrigatório para instrutor/aluno). */
        String academySlug,
        String deviceId,
        String deviceLabel,
        AppClientType appClient,
        String appVersion
) {}
