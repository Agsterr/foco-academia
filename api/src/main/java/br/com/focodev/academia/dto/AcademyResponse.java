package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Academy;

import java.time.Instant;
import java.util.UUID;

public record AcademyResponse(
        UUID id,
        String name,
        int deviceLimitPerUser,
        boolean active,
        Instant createdAt,
        long instructorCount,
        long studentCount
) {
    public static AcademyResponse from(Academy academy, long instructors, long students) {
        return new AcademyResponse(
                academy.getId(),
                academy.getName(),
                academy.getDeviceLimitPerUser(),
                academy.isActive(),
                academy.getCreatedAt(),
                instructors,
                students
        );
    }
}
