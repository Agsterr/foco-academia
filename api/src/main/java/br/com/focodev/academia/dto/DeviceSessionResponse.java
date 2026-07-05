package br.com.focodev.academia.dto;

import java.time.Instant;
import java.util.UUID;

public record DeviceSessionResponse(
        UUID id,
        String deviceId,
        String deviceLabel,
        Instant lastSeenAt
) {}
