package br.com.focodev.academia.controller;

import br.com.focodev.academia.domain.AppRelease;
import br.com.focodev.academia.dto.AppReleaseDtos;
import br.com.focodev.academia.service.AppReleaseService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.UUID;

@RestController
@RequestMapping("/api/app")
@RequiredArgsConstructor
public class AppReleaseController {

    private final AppReleaseService appReleaseService;

    @GetMapping("/version")
    public AppReleaseDtos.AppVersionCheckResponse latestVersion() {
        return appReleaseService.getLatestVersion();
    }

    @GetMapping("/download/latest")
    public ResponseEntity<Resource> downloadLatest() {
        return buildDownloadResponse(appReleaseService.getLatestReleaseEntity());
    }

    @GetMapping("/download/{id}")
    public ResponseEntity<Resource> downloadById(@PathVariable UUID id) {
        return buildDownloadResponse(appReleaseService.getReleaseEntity(id));
    }

    @PostMapping(value = "/releases/deploy", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public AppReleaseDtos.AdminAppReleaseResponse deployRelease(
            @RequestHeader("X-Deploy-Token") String deployToken,
            @RequestPart("file") MultipartFile file,
            @RequestPart("versionName") String versionName,
            @RequestPart("versionCode") String versionCodeRaw,
            @RequestParam(required = false) String releaseNotes,
            @RequestParam(defaultValue = "false") boolean forceUpdate
    ) {
        appReleaseService.validateDeployToken(deployToken);
        return appReleaseService.publishRelease(
                file,
                versionName,
                parseVersionCode(versionCodeRaw),
                releaseNotes,
                forceUpdate
        );
    }

    private ResponseEntity<Resource> buildDownloadResponse(AppRelease release) {
        Resource resource = appReleaseService.loadApkResource(release);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + release.getFileName() + "\"")
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .contentLength(release.getFileSizeBytes())
                .body(resource);
    }

    private static int parseVersionCode(String raw) {
        try {
            return Integer.parseInt(raw.trim());
        } catch (NumberFormatException ex) {
            throw new br.com.focodev.academia.exception.ApiException("versionCode inválido");
        }
    }
}
