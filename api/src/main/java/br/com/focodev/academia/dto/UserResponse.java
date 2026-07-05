package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;

import java.time.Instant;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String email,
        String name,
        String phone,
        UserRole role,
        UUID academyId,
        String academyName,
        String academySlug,
        UUID instructorId,
        Instant lastLoginAt
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getPhone(),
                user.getRole(),
                user.getAcademy() != null ? user.getAcademy().getId() : null,
                user.getAcademy() != null ? user.getAcademy().getName() : null,
                user.getAcademy() != null ? user.getAcademy().getSlug() : null,
                user.getInstructor() != null ? user.getInstructor().getId() : null,
                user.getLastLoginAt()
        );
    }
}
