package br.com.focodev.academia.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.releases")
public record AppReleaseProperties(
        String storagePath,
        int maxRetained,
        String deployToken,
        String publicBaseUrl
) {
    public AppReleaseProperties {
        if (storagePath == null || storagePath.isBlank()) {
            storagePath = "/app/releases";
        }
        if (maxRetained < 1) {
            maxRetained = 2;
        }
        if (deployToken == null) {
            deployToken = "";
        }
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            publicBaseUrl = "https://academia.focodev.com.br";
        }
    }
}
