package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.AppClientType;
import jakarta.validation.constraints.Size;

public record HeartbeatRequest(
        @Size(max = 128) String deviceId,
        @Size(max = 64) String appVersion,
        AppClientType appClient
) {}
