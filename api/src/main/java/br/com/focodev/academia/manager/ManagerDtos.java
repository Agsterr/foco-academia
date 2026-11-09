package br.com.focodev.academia.manager;

import br.com.focodev.academia.dto.UserResponse;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public final class ManagerDtos {

    private ManagerDtos() {}

    /** ACADEMIA: academia com vários instrutores · INSTRUTOR_AUTONOMO: personal que trabalha sozinho. */
    public enum BusinessType { ACADEMIA, INSTRUTOR_AUTONOMO }

    public record RegisterBusinessRequest(
            @NotNull BusinessType type,
            /** Nome da academia (ignorado para instrutor autônomo, que usa o próprio nome). */
            @Size(max = 120) String academyName,
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, max = 100) String password,
            String deviceId,
            String deviceLabel,
            br.com.focodev.academia.domain.AppClientType appClient,
            String appVersion
    ) {}

    public record RegisterBusinessResponse(String token, UserResponse user, String academySlug) {}

    public record CreatePersonRequest(
            @NotBlank @Size(max = 120) String name,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, max = 100) String password,
            /** Só para aluno: instrutor responsável (vazio = o próprio gestor/autônomo decide depois). */
            UUID instructorId
    ) {}

    public record AssignInstructorRequest(@NotNull UUID instructorId) {}

    public record RespondRequest(@NotBlank @Size(max = 2000) String response) {}

    /** Um mês no gráfico: treinos concluídos e alunos que treinaram. */
    public record MonthPoint(String month, long sessions, long activeStudents) {}

    public record InstructorStats(
            UUID id,
            String name,
            String email,
            boolean active,
            long students,
            long sessions30d,
            Double averageRating,
            long pendingSuggestions
    ) {}

    public record StudentStats(
            UUID id,
            String name,
            String email,
            boolean active,
            UUID instructorId,
            String instructorName,
            Instant lastActivityAt,
            long sessions30d,
            Double averageRating
    ) {}

    public record RatingEntry(
            UUID studentId,
            String studentName,
            String instructorName,
            String rating,
            int score,
            String comment,
            String workout,
            Instant at
    ) {}

    public record SuggestionEntry(
            UUID id,
            String studentName,
            String instructorName,
            String category,
            String message,
            String status,
            String response,
            Instant createdAt
    ) {}

    public record Dashboard(
            String academyName,
            String academySlug,
            boolean personal,
            BigDecimal planMonthlyPrice,
            int planIncludedStudents,
            long instructors,
            long students,
            long activeStudents7d,
            long sessions30d,
            Double averageRating30d,
            long pendingSuggestions,
            /** Contagem de notas dos últimos 30 dias por nível (MUITO_BOM … MUITO_RUIM). */
            Map<String, Long> ratingDistribution,
            List<MonthPoint> months,
            List<InstructorStats> instructorRanking
    ) {}
}
