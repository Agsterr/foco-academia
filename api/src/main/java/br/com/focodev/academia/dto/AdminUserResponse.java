package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.UserRole;

import java.time.Instant;
import java.util.UUID;

public record AdminUserResponse(
        UUID id,
        String email,
        String name,
        String phone,
        UserRole role,
        UUID academyId,
        String academyName,
        UUID instructorId,
        Instant lastLoginAt,
        long deviceCount,
        boolean active
) {}
