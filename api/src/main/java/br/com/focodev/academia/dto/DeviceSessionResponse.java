package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.AppClientType;

import java.time.Instant;
import java.util.UUID;

public record DeviceSessionResponse(
        UUID id,
        String deviceId,
        String deviceLabel,
        AppClientType appClient,
        String appVersion,
        Instant lastSeenAt
) {}
