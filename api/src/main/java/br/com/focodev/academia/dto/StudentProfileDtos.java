package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.ActivityLevel;
import br.com.focodev.academia.domain.BiologicalSex;
import br.com.focodev.academia.domain.FitnessGoal;
import jakarta.validation.constraints.*;

import java.time.LocalDate;
import java.util.UUID;

public final class StudentProfileDtos {

    private StudentProfileDtos() {}

    public record OnboardingRequest(
            @NotNull @DecimalMin("50") @DecimalMax("250") Double heightCm,
            @NotNull @DecimalMin("20") @DecimalMax("500") Double weightKg,
            @NotNull FitnessGoal goal,
            BiologicalSex sex,
            LocalDate birthDate,
            ActivityLevel activityLevel
    ) {}

    public record UpdateProfileRequest(
            @DecimalMin("50") @DecimalMax("250") Double heightCm,
            @DecimalMin("20") @DecimalMax("500") Double weightKg,
            FitnessGoal goal,
            BiologicalSex sex,
            LocalDate birthDate,
            ActivityLevel activityLevel
    ) {}

    public record StudentProfileResponse(
            UUID studentId,
            String studentName,
            Double heightCm,
            Double currentWeightKg,
            FitnessGoal goal,
            boolean onboardingCompleted,
            BiologicalSex sex,
            LocalDate birthDate,
            Integer age,
            ActivityLevel activityLevel
    ) {}

    public record ProfileStatusResponse(
            boolean onboardingCompleted,
            boolean pendingWeightCheck,
            WeightCheckScheduleResponse pendingWeightSchedule,
            boolean suggestGoalCheckIn
    ) {}

    public record BodyMeasurementRequest(
            @NotNull @DecimalMin("20") @DecimalMax("500") Double weightKg,
            Double waistCm,
            Double hipsCm,
            Double chestCm,
            String notes,
            /** Opcional: STUDENT, SCALE_BLE, WATCH, IMPORT */
            String source
    ) {}

    public record BodyMeasurementResponse(
            UUID id,
            Double weightKg,
            Double waistCm,
            Double hipsCm,
            Double chestCm,
            String recordedAt,
            String source,
            String notes
    ) {}

    public record WeightCheckScheduleRequest(
            @NotNull java.time.LocalDate dueDate
    ) {}

    public record WeightCheckScheduleResponse(
            UUID id,
            UUID studentId,
            String studentName,
            java.time.LocalDate dueDate,
            boolean completed,
            boolean overdue
    ) {}

    public record GoalCheckInRequest(
            boolean achievingGoal,
            @Min(1) @Max(5) int progressRating,
            @Size(max = 2000) String comment
    ) {}

    public record GoalCheckInResponse(
            UUID id,
            boolean achievingGoal,
            int progressRating,
            String comment,
            String createdAt
    ) {}

    public record QuickProgramRequest(
            @NotNull UUID studentId
    ) {}
}
