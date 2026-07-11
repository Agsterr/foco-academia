package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.FitnessGoal;
import br.com.focodev.academia.domain.WeekDay;
import br.com.focodev.academia.dto.CreateWorkoutProgramRequest;
import br.com.focodev.academia.dto.ExerciseRequest;
import br.com.focodev.academia.dto.WorkoutDayRequest;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public final class QuickWorkoutTemplates {

    private QuickWorkoutTemplates() {}

    public static CreateWorkoutProgramRequest build(FitnessGoal goal, UUID studentId) {
        return switch (goal) {
            case EMAGRECER -> emagrecer(studentId);
            case GANHAR_MASSA -> ganharMassa(studentId);
            case CORRIDA, CONDICIONAMENTO -> condicionamento(studentId);
            case ALONGAMENTO -> alongamento(studentId);
            case MANUTENCAO -> manutencao(studentId);
        };
    }

    private static CreateWorkoutProgramRequest emagrecer(UUID studentId) {
        return new CreateWorkoutProgramRequest(
                "Treino rápido — Emagrecimento",
                "Ficha gerada automaticamente com foco em queima calórica.",
                studentId,
                List.of(
                        day(WeekDay.MONDAY, "Full body + cardio", exercises(
                                ex("Agachamento livre", 3, 15),
                                ex("Supino reto", 3, 12),
                                ex("Remada curvada", 3, 12),
                                ex("Esteira caminhada", 1, 0, "20 min")
                        ), 1),
                        day(WeekDay.TUESDAY, "Cardio", exercises(ex("Caminhada ou bike", 1, 0, "30 min")), 2),
                        day(WeekDay.WEDNESDAY, "Full body", exercises(
                                ex("Leg press", 3, 15),
                                ex("Desenvolvimento", 3, 12),
                                ex("Puxada frontal", 3, 12)
                        ), 3),
                        day(WeekDay.THURSDAY, "Descanso ativo", exercises(ex("Alongamento leve", 1, 0, "15 min")), 4),
                        day(WeekDay.FRIDAY, "Full body", exercises(
                                ex("Levantamento terra", 3, 10),
                                ex("Afundo", 3, 12),
                                ex("Abdominal prancha", 3, 0, "45s")
                        ), 5),
                        rest(WeekDay.SATURDAY, 6),
                        rest(WeekDay.SUNDAY, 7)
                )
        );
    }

    private static CreateWorkoutProgramRequest ganharMassa(UUID studentId) {
        return new CreateWorkoutProgramRequest(
                "Treino rápido — Ganho de massa",
                "Ficha gerada automaticamente com foco em hipertrofia.",
                studentId,
                List.of(
                        day(WeekDay.MONDAY, "Peito e tríceps", exercises(
                                ex("Supino reto", 4, 8),
                                ex("Supino inclinado", 3, 10),
                                ex("Crucifixo", 3, 12),
                                ex("Tríceps pulley", 3, 12)
                        ), 1),
                        day(WeekDay.TUESDAY, "Costas e bíceps", exercises(
                                ex("Barra fixa", 4, 8),
                                ex("Remada curvada", 3, 10),
                                ex("Rosca direta", 3, 12)
                        ), 2),
                        day(WeekDay.WEDNESDAY, "Pernas", exercises(
                                ex("Agachamento livre", 4, 8),
                                ex("Leg press", 3, 12),
                                ex("Cadeira extensora", 3, 12),
                                ex("Mesa flexora", 3, 12)
                        ), 3),
                        day(WeekDay.THURSDAY, "Ombros", exercises(
                                ex("Desenvolvimento", 4, 8),
                                ex("Elevação lateral", 3, 12),
                                ex("Encolhimento", 3, 12)
                        ), 4),
                        day(WeekDay.FRIDAY, "Full body pesado", exercises(
                                ex("Levantamento terra", 4, 6),
                                ex("Supino reto", 3, 8),
                                ex("Agachamento", 3, 8)
                        ), 5),
                        rest(WeekDay.SATURDAY, 6),
                        rest(WeekDay.SUNDAY, 7)
                )
        );
    }

    private static CreateWorkoutProgramRequest condicionamento(UUID studentId) {
        return new CreateWorkoutProgramRequest(
                "Treino rápido — Condicionamento",
                "Ficha com cardio e funcional para corrida/caminhada.",
                studentId,
                List.of(
                        day(WeekDay.MONDAY, "Caminhada intervalada", exercises(ex("Caminhada/corrida leve", 1, 0, "25 min")), 1),
                        day(WeekDay.TUESDAY, "Funcional", exercises(
                                ex("Polichinelo", 3, 20),
                                ex("Agachamento", 3, 15),
                                ex("Prancha", 3, 0, "40s")
                        ), 2),
                        day(WeekDay.WEDNESDAY, "Corrida leve", exercises(ex("Corrida contínua", 1, 0, "20 min")), 3),
                        day(WeekDay.THURSDAY, "Alongamento", exercises(ex("Alongamento geral", 1, 0, "20 min")), 4),
                        day(WeekDay.FRIDAY, "HIIT leve", exercises(ex("Intervalos caminhada/corrida", 1, 0, "20 min")), 5),
                        rest(WeekDay.SATURDAY, 6),
                        rest(WeekDay.SUNDAY, 7)
                )
        );
    }

    private static CreateWorkoutProgramRequest alongamento(UUID studentId) {
        return new CreateWorkoutProgramRequest(
                "Treino rápido — Alongamento",
                "Ficha focada em mobilidade e flexibilidade.",
                studentId,
                List.of(
                        day(WeekDay.MONDAY, "Membros inferiores", exercises(ex("Alongamento pernas", 1, 0, "25 min")), 1),
                        day(WeekDay.TUESDAY, "Coluna e core", exercises(ex("Mobilidade coluna", 1, 0, "20 min")), 2),
                        day(WeekDay.WEDNESDAY, "Membros superiores", exercises(ex("Alongamento braços/ombros", 1, 0, "20 min")), 3),
                        day(WeekDay.THURSDAY, "Yoga leve", exercises(ex("Sequência yoga", 1, 0, "25 min")), 4),
                        day(WeekDay.FRIDAY, "Corpo inteiro", exercises(ex("Alongamento completo", 1, 0, "30 min")), 5),
                        rest(WeekDay.SATURDAY, 6),
                        rest(WeekDay.SUNDAY, 7)
                )
        );
    }

    private static CreateWorkoutProgramRequest manutencao(UUID studentId) {
        return condicionamento(studentId);
    }

    private static WorkoutDayRequest day(WeekDay weekDay, String group, List<ExerciseRequest> exercises, int order) {
        return new WorkoutDayRequest(weekDay, group, null, false, order, exercises);
    }

    private static WorkoutDayRequest rest(WeekDay weekDay, int order) {
        return new WorkoutDayRequest(weekDay, "Descanso", null, true, order, List.of());
    }

    private static List<ExerciseRequest> exercises(ExerciseRequest... items) {
        List<ExerciseRequest> list = new ArrayList<>();
        int i = 0;
        for (ExerciseRequest item : items) {
            list.add(new ExerciseRequest(
                    item.name(), item.description(), item.sets(), item.reps(),
                    item.duration(), item.videoUrl(), item.mediaType(),
                    item.variationNotes(), item.notes(), i++
            ));
        }
        return list;
    }

    private static ExerciseRequest ex(String name, int sets, int reps) {
        return ex(name, sets, reps, null);
    }

    private static ExerciseRequest ex(String name, int sets, int reps, String duration) {
        return new ExerciseRequest(name, null, sets, reps, duration, null, null, null, null, 0);
    }
}
