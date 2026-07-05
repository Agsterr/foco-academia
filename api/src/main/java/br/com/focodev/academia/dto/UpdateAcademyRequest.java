package br.com.focodev.academia.dto;

import jakarta.validation.constraints.*;

public record UpdateAcademyRequest(
        @Size(max = 120) String name,
        @Min(1) @Max(20) Integer deviceLimitPerUser,
        Boolean active
) {}
