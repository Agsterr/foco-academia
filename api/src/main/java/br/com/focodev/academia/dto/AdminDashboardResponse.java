package br.com.focodev.academia.dto;

public record AdminDashboardResponse(
        long totalAcademies,
        long activeAcademies,
        long totalInstructors,
        long totalStudents
) {}
