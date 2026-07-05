package br.com.focodev.academia.dto;

import jakarta.validation.constraints.*;

import java.util.UUID;

public record CreateAcademyStudentRequest(
        @NotBlank @Size(max = 120) String name,
        @NotBlank @Email String email,
        @NotBlank @Size(min = 6, max = 100) String password,
        String phone,
        @NotNull UUID instructorId
) {}
