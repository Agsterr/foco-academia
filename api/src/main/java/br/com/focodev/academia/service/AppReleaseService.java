package br.com.focodev.academia.service;

import br.com.focodev.academia.config.AppReleaseProperties;
import br.com.focodev.academia.domain.AppRelease;
import br.com.focodev.academia.domain.DeviceSession;
import br.com.focodev.academia.dto.AppReleaseDtos;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.AppReleaseRepository;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AppReleaseService {

    private final AppReleaseRepository repository;
    private final DeviceSessionRepository deviceSessionRepository;
    private final AppReleaseProperties properties;

    @Transactional(readOnly = true)
    public AppReleaseDtos.AppVersionCheckResponse getLatestVersion() {
        AppRelease release = repository.findFirstByActiveTrueOrderByVersionCodeDescCreatedAtDesc()
                .orElseThrow(() -> new ApiException("Nenhuma versão publicada", HttpStatus.NOT_FOUND));
        return toVersionCheck(release);
    }

    @Transactional(readOnly = true)
    public List<AppReleaseDtos.AdminAppReleaseResponse> listActiveReleases() {
        return repository.findByActiveTrueOrderByVersionCodeDescCreatedAtDesc().stream()
                .map(this::toAdminResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public AppRelease getLatestReleaseEntity() {
        return repository.findFirstByActiveTrueOrderByVersionCodeDescCreatedAtDesc()
                .orElseThrow(() -> new ApiException("Nenhuma versão publicada", HttpStatus.NOT_FOUND));
    }

    @Transactional(readOnly = true)
    public AppRelease getReleaseEntity(UUID id) {
        return repository.findById(id)
                .filter(AppRelease::isActive)
                .orElseThrow(() -> new ApiException("Release não encontrada", HttpStatus.NOT_FOUND));
    }

    @Transactional(readOnly = true)
    public Resource loadApkResource(AppRelease release) {
        Path path = resolveStoragePath(release.getFileName());
        if (!Files.isRegularFile(path)) {
            throw new ApiException("Arquivo APK não encontrado no servidor", HttpStatus.NOT_FOUND);
        }
        try {
            return new UrlResource(path.toUri());
        } catch (IOException ex) {
            throw new ApiException("Erro ao ler APK", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    @Transactional
    public AppReleaseDtos.AdminAppReleaseResponse publishRelease(
            MultipartFile file,
            String versionName,
            int versionCode,
            String releaseNotes,
            boolean forceUpdate
    ) {
        validateApkFile(file);
        if (versionName == null || versionName.isBlank()) {
            throw new ApiException("versionName é obrigatório");
        }
        if (versionCode < 1) {
            throw new ApiException("versionCode inválido");
        }
        if (repository.existsByVersionCode(versionCode)) {
            throw new ApiException("versionCode já publicado", HttpStatus.CONFLICT);
        }

        ensureStorageDirectory();
        String safeFileName = "foco-academia-v" + versionCode + ".apk";
        Path target = resolveStoragePath(safeFileName);

        try {
            file.transferTo(target);
        } catch (IOException ex) {
            throw new ApiException("Falha ao salvar APK", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        String sha256;
        long size;
        try {
            sha256 = computeSha256(target);
            size = Files.size(target);
        } catch (IOException ex) {
            deleteQuietly(target);
            throw new ApiException("Falha ao validar APK", HttpStatus.INTERNAL_SERVER_ERROR);
        }

        AppRelease release = new AppRelease();
        release.setVersionName(versionName.trim());
        release.setVersionCode(versionCode);
        release.setFileName(safeFileName);
        release.setFileSizeBytes(size);
        release.setSha256(sha256);
        release.setReleaseNotes(truncateNotes(releaseNotes));
        release.setForceUpdate(forceUpdate);
        release.setActive(true);

        AppRelease saved = repository.save(release);
        pruneOldReleases();
        return toAdminResponse(saved);
    }

    @Transactional
    public AppReleaseDtos.AdminAppReleaseResponse updateForceUpdate(UUID id, boolean forceUpdate) {
        AppRelease release = getReleaseEntity(id);
        release.setForceUpdate(forceUpdate);
        return toAdminResponse(repository.save(release));
    }

    @Transactional(readOnly = true)
    public List<AppReleaseDtos.AdminConnectedDeviceResponse> listConnectedDevices() {
        int latestVersionCode = repository.findFirstByActiveTrueOrderByVersionCodeDescCreatedAtDesc()
                .map(AppRelease::getVersionCode)
                .orElse(0);

        return deviceSessionRepository.findByAppClientWithUser(br.com.focodev.academia.domain.AppClientType.MOBILE).stream()
                .map(session -> toConnectedDevice(session, latestVersionCode))
                .toList();
    }

    public void validateDeployToken(String token) {
        String expected = properties.deployToken();
        if (expected == null || expected.isBlank()) {
            throw new ApiException("Deploy token não configurado no servidor", HttpStatus.SERVICE_UNAVAILABLE);
        }
        if (token == null || !expected.equals(token)) {
            throw new ApiException("Token de deploy inválido", HttpStatus.FORBIDDEN);
        }
    }

    private void validateApkFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new ApiException("Arquivo APK é obrigatório");
        }
        String name = file.getOriginalFilename();
        if (name == null || !name.toLowerCase().endsWith(".apk")) {
            throw new ApiException("Envie um arquivo .apk");
        }
    }

    private void ensureStorageDirectory() {
        try {
            Files.createDirectories(Path.of(properties.storagePath()));
        } catch (IOException ex) {
            throw new ApiException("Diretório de releases indisponível", HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private Path resolveStoragePath(String fileName) {
        return Path.of(properties.storagePath()).resolve(fileName).normalize();
    }

    private void pruneOldReleases() {
        List<AppRelease> active = repository.findByActiveTrueOrderByVersionCodeDescCreatedAtDesc();
        if (active.size() <= properties.maxRetained()) {
            return;
        }
        for (int i = properties.maxRetained(); i < active.size(); i++) {
            AppRelease old = active.get(i);
            old.setActive(false);
            repository.save(old);
            deleteQuietly(resolveStoragePath(old.getFileName()));
        }
    }

    private static void deleteQuietly(Path path) {
        try {
            Files.deleteIfExists(path);
        } catch (IOException ignored) {
        }
    }

    private static String computeSha256(Path path) throws IOException {
        MessageDigest digest;
        try {
            digest = MessageDigest.getInstance("SHA-256");
        } catch (Exception ex) {
            throw new IOException(ex);
        }
        try (InputStream input = Files.newInputStream(path);
             DigestInputStream digestStream = new DigestInputStream(input, digest)) {
            digestStream.transferTo(OutputStream.nullOutputStream());
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private AppReleaseDtos.AppVersionCheckResponse toVersionCheck(AppRelease release) {
        String base = properties.publicBaseUrl().replaceAll("/$", "");
        return new AppReleaseDtos.AppVersionCheckResponse(
                release.getVersionName(),
                release.getVersionCode(),
                base + "/api/app/download/latest",
                release.getReleaseNotes(),
                release.isForceUpdate(),
                release.getSha256()
        );
    }

    private AppReleaseDtos.AdminAppReleaseResponse toAdminResponse(AppRelease release) {
        String base = properties.publicBaseUrl().replaceAll("/$", "");
        return new AppReleaseDtos.AdminAppReleaseResponse(
                release.getId(),
                release.getVersionName(),
                release.getVersionCode(),
                release.getFileName(),
                release.getFileSizeBytes(),
                release.getSha256(),
                release.getReleaseNotes(),
                release.isForceUpdate(),
                release.isActive(),
                base + "/api/app/download/" + release.getId(),
                release.getCreatedAt()
        );
    }

    private AppReleaseDtos.AdminConnectedDeviceResponse toConnectedDevice(DeviceSession session, int latestVersionCode) {
        Integer deviceCode = parseAppVersionCode(session.getAppVersion());
        boolean needsUpdate = deviceCode == null || deviceCode < latestVersionCode;
        return new AppReleaseDtos.AdminConnectedDeviceResponse(
                session.getId(),
                session.getUser().getId(),
                session.getUser().getName(),
                session.getUser().getEmail(),
                session.getDeviceId(),
                session.getDeviceLabel(),
                session.getAppClient() != null ? session.getAppClient().name() : "WEB",
                session.getAppVersion(),
                deviceCode,
                needsUpdate,
                session.getLastSeenAt()
        );
    }

    static Integer parseAppVersionCode(String appVersion) {
        if (appVersion == null || appVersion.isBlank()) {
            return null;
        }
        int plus = appVersion.lastIndexOf('+');
        if (plus < 0 || plus >= appVersion.length() - 1) {
            return null;
        }
        try {
            return Integer.parseInt(appVersion.substring(plus + 1).trim());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static String truncateNotes(String releaseNotes) {
        if (releaseNotes == null) {
            return null;
        }
        String notes = releaseNotes.trim();
        if (notes.isEmpty()) {
            return null;
        }
        final int max = 2000;
        return notes.length() <= max ? notes : notes.substring(0, max);
    }
}
