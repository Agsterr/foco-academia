package br.com.focodev.academia.dto;

public record AuthResponse(
        String token,
        UserResponse user
) {}
