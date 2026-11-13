package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.ActivityLevel;
import br.com.focodev.academia.domain.BiologicalSex;
import br.com.focodev.academia.domain.FitnessGoal;
import jakarta.validation.constraints.*;

import java.time.LocalDate;
import java.util.UUID;

public final class StudentProfileDtos {

    private StudentProfileDtos() {}

    static final String HEIGHT_MESSAGE = "Altura deve estar entre 50 e 250 cm. Ex.: 170";
    static final String WEIGHT_MESSAGE = "Peso deve estar entre 20 e 500 kg. Ex.: 78,5";

    public record OnboardingRequest(
            @NotNull(message = "Informe a altura") @DecimalMin(value = "50", message = HEIGHT_MESSAGE) @DecimalMax(value = "250", message = HEIGHT_MESSAGE) Double heightCm,
            @NotNull(message = "Informe o peso") @DecimalMin(value = "20", message = WEIGHT_MESSAGE) @DecimalMax(value = "500", message = WEIGHT_MESSAGE) Double weightKg,
            @NotNull FitnessGoal goal,
            BiologicalSex sex,
            LocalDate birthDate,
            ActivityLevel activityLevel
    ) {}

    public record UpdateProfileRequest(
            @DecimalMin(value = "50", message = HEIGHT_MESSAGE) @DecimalMax(value = "250", message = HEIGHT_MESSAGE) Double heightCm,
            @DecimalMin(value = "20", message = WEIGHT_MESSAGE) @DecimalMax(value = "500", message = WEIGHT_MESSAGE) Double weightKg,
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
            @NotNull(message = "Informe o peso") @DecimalMin(value = "20", message = WEIGHT_MESSAGE) @DecimalMax(value = "500", message = WEIGHT_MESSAGE) Double weightKg,
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
