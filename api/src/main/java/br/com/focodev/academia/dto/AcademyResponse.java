package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.Academy;

import java.time.Instant;
import java.util.UUID;

public record AcademyResponse(
        UUID id,
        String name,
        String slug,
        int deviceLimitPerUser,
        boolean active,
        boolean appBlocked,
        Instant createdAt,
        long instructorCount,
        long studentCount,
        /** Mensalidade da academia (R$), com todos os instrutores incluídos. */
        java.math.BigDecimal planMonthlyPrice,
        int planIncludedStudents
) {
    public static AcademyResponse from(Academy academy, long instructors, long students,
                                       java.math.BigDecimal monthlyPrice, int includedStudents) {
        return new AcademyResponse(
                academy.getId(),
                academy.getName(),
                academy.getSlug(),
                academy.getDeviceLimitPerUser(),
                academy.isActive(),
                academy.isAppBlocked(),
                academy.getCreatedAt(),
                instructors,
                students,
                monthlyPrice,
                includedStudents
        );
    }
}
