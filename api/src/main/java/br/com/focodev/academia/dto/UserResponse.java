package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;

import java.util.UUID;

public record UserResponse(
        UUID id,
        String email,
        String name,
        String phone,
        UserRole role,
        UUID instructorId
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getEmail(),
                user.getName(),
                user.getPhone(),
                user.getRole(),
                user.getInstructor() != null ? user.getInstructor().getId() : null
        );
    }
}
