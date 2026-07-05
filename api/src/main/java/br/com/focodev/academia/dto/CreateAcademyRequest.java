package br.com.focodev.academia.dto;

import jakarta.validation.constraints.*;

public record CreateAcademyRequest(
        @NotBlank @Size(max = 120) String name,
        @Size(max = 64) String slug,
        @Min(1) @Max(20) int deviceLimitPerUser,
        @NotBlank @Size(max = 120) String instructorName,
        @NotBlank @Email String instructorEmail,
        @NotBlank @Size(min = 6, max = 100) String instructorPassword,
        String instructorPhone
) {}
