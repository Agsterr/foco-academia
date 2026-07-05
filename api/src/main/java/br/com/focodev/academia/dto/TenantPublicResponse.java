package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Academy;

public record TenantPublicResponse(
        String slug,
        String name
) {
    public static TenantPublicResponse from(Academy academy) {
        return new TenantPublicResponse(academy.getSlug(), academy.getName());
    }
}
