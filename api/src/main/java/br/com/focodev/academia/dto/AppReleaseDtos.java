package br.com.focodev.academia.dto;

import java.time.Instant;
import java.util.UUID;

public final class AppReleaseDtos {

    private AppReleaseDtos() {}

    public record AppVersionCheckResponse(
            String versionName,
            int versionCode,
            String downloadUrl,
            String releaseNotes,
            boolean forceUpdate,
            String sha256
    ) {}

    public record AdminAppReleaseResponse(
            UUID id,
            String versionName,
            int versionCode,
            String fileName,
            long fileSizeBytes,
            String sha256,
            String releaseNotes,
            boolean forceUpdate,
            boolean active,
            String downloadUrl,
            Instant createdAt
    ) {}

    public record UpdateForceReleaseRequest(boolean forceUpdate) {}

    public record AdminConnectedDeviceResponse(
            UUID sessionId,
            UUID userId,
            String userName,
            String userEmail,
            String deviceId,
            String deviceLabel,
            String appClient,
            String appVersion,
            Integer appVersionCode,
            boolean needsUpdate,
            Instant lastSeenAt
    ) {}
}
