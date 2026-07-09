package br.com.focodev.academia.dto;

import br.com.focodev.academia.domain.WorkoutProgram;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record WorkoutProgramResponse(
        UUID id,
        String title,
        String description,
        boolean active,
        Instant createdAt,
        UserResponse student,
        List<WorkoutDayResponse> days
) {
    public static WorkoutProgramResponse from(WorkoutProgram program) {
        return new WorkoutProgramResponse(
                program.getId(),
                program.getTitle(),
                program.getDescription(),
                program.isActive(),
                program.getCreatedAt(),
                UserResponse.from(program.getStudent()),
                program.getDays().stream().map(WorkoutDayResponse::from).toList()
        );
    }

    public static WorkoutProgramResponse from(WorkoutProgram program, List<WorkoutDayResponse> days) {
        return new WorkoutProgramResponse(
                program.getId(),
                program.getTitle(),
                program.getDescription(),
                program.isActive(),
                program.getCreatedAt(),
                UserResponse.from(program.getStudent()),
                days
        );
    }
}
