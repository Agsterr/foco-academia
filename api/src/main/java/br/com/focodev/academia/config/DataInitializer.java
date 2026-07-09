package br.com.focodev.academia.config;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.repository.WorkoutProgramRepository;
import br.com.focodev.academia.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

@Configuration
@RequiredArgsConstructor
public class DataInitializer {

    private final UserRepository userRepository;
    private final AcademyRepository academyRepository;
    private final WorkoutRepository workoutRepository;
    private final WorkoutProgramRepository programRepository;
    private final PasswordEncoder passwordEncoder;

    @Bean
    @Order(1)
    CommandLineRunner seedData() {
        return args -> {
            Academy academy = academyRepository.findAll().stream().findFirst().orElseGet(() -> {
                Academy a = new Academy();
                a.setName("Academia Demo");
                a.setSlug("academia-demo");
                a.setDeviceLimitPerUser(3);
                return academyRepository.save(a);
            });

            if (academy.getSlug() == null || academy.getSlug().isBlank()) {
                academy.setSlug("academia-demo");
                academyRepository.save(academy);
            }

            String adminPassword = envOrNull("SEED_ADMIN_PASSWORD");
            if (adminPassword != null && !userRepository.existsByRole(UserRole.ADMIN)) {
                User admin = new User();
                admin.setEmail("admin@focodev.com.br");
                admin.setPasswordHash(passwordEncoder.encode(adminPassword));
                admin.setName("Administrador FocoDev");
                admin.setRole(UserRole.ADMIN);
                userRepository.save(admin);
            }

            List<User> orphans = userRepository.findAll().stream()
                    .filter(u -> u.getAcademy() == null && u.getRole() != UserRole.ADMIN)
                    .toList();
            for (User u : orphans) {
                u.setAcademy(academy);
                userRepository.save(u);
            }

            String instructorPassword = envOrNull("SEED_INSTRUTOR_PASSWORD");
            String studentPassword = envOrNull("SEED_ALUNO_PASSWORD");
            if (instructorPassword != null
                    && studentPassword != null
                    && userRepository.findByEmailIgnoreCase("instrutor@academia.com").isEmpty()) {
                User instructor = new User();
                instructor.setEmail("instrutor@academia.com");
                instructor.setPasswordHash(passwordEncoder.encode(instructorPassword));
                instructor.setName("Instrutor Demo");
                instructor.setRole(UserRole.INSTRUTOR);
                instructor.setAcademy(academy);
                userRepository.save(instructor);

                User student = new User();
                student.setEmail("aluno@academia.com");
                student.setPasswordHash(passwordEncoder.encode(studentPassword));
                student.setName("Aluno Demo");
                student.setRole(UserRole.ALUNO);
                student.setAcademy(academy);
                student.setInstructor(instructor);
                userRepository.save(student);

                Workout workout = new Workout();
                workout.setTitle("Treino A — Peito e Tríceps");
                workout.setDescription("Foco em força com descanso de 60s entre séries.");
                workout.setInstructor(instructor);
                workout.setStudent(student);
                workout.setStatus(WorkoutStatus.ATIVO);

                Exercise ex1 = new Exercise();
                ex1.setWorkout(workout);
                ex1.setName("Supino reto");
                ex1.setSets(4);
                ex1.setReps(10);
                ex1.setNotes("Controle a descida em 3 segundos");
                ex1.setSortOrder(0);

                Exercise ex2 = new Exercise();
                ex2.setWorkout(workout);
                ex2.setName("Tríceps na polia");
                ex2.setSets(3);
                ex2.setReps(12);
                ex2.setSortOrder(1);

                workout.getExercises().add(ex1);
                workout.getExercises().add(ex2);
                workoutRepository.save(workout);

                WorkoutProgram program = new WorkoutProgram();
                program.setTitle("Ficha Semanal — Hipertrofia");
                program.setDescription("Programa completo de segunda a domingo.");
                program.setInstructor(instructor);
                program.setStudent(student);

                program.getDays().add(buildDay(program, WeekDay.MONDAY, "Peito e Tríceps", 0,
                        exercise("Supino reto", 4, 10, "Controle a descida", 0),
                        exercise("Crucifixo", 3, 12, null, 1)));
                program.getDays().add(buildDay(program, WeekDay.TUESDAY, "Costas e Bíceps", 1,
                        exercise("Puxada frontal", 4, 10, null, 0),
                        exercise("Rosca direta", 3, 12, null, 1)));
                program.getDays().add(buildDay(program, WeekDay.WEDNESDAY, "Pernas", 2,
                        exercise("Agachamento", 4, 10, null, 0),
                        exercise("Leg press", 3, 12, null, 1)));
                program.getDays().add(buildDay(program, WeekDay.THURSDAY, "Ombros e Abdômen", 3,
                        exercise("Desenvolvimento", 4, 10, null, 0)));
                program.getDays().add(buildDay(program, WeekDay.FRIDAY, "Bíceps e Tríceps", 4,
                        exercise("Rosca martelo", 3, 12, null, 0),
                        exercise("Tríceps testa", 3, 12, null, 1)));
                program.getDays().add(buildDay(program, WeekDay.SATURDAY, "Cardio", 5,
                        exercise("Esteira", 1, 1, "30 minutos moderado", 0)));
                program.getDays().add(buildRestDay(program, WeekDay.SUNDAY, 6));

                programRepository.save(program);
            }
        };
    }

    private static WorkoutDay buildRestDay(WorkoutProgram program, WeekDay weekDay, int sortOrder) {
        WorkoutDay day = new WorkoutDay();
        day.setProgram(program);
        day.setWeekDay(weekDay);
        day.setMuscleGroup("Descanso");
        day.setRestDay(true);
        day.setSortOrder(sortOrder);
        return day;
    }

    private static WorkoutDay buildDay(WorkoutProgram program, WeekDay weekDay, String muscleGroup,
                                       int sortOrder, Exercise... exercises) {
        WorkoutDay day = new WorkoutDay();
        day.setProgram(program);
        day.setWeekDay(weekDay);
        day.setMuscleGroup(muscleGroup);
        day.setRestDay(false);
        day.setSortOrder(sortOrder);
        for (Exercise exercise : exercises) {
            exercise.setWorkoutDay(day);
            day.getExercises().add(exercise);
        }
        return day;
    }

    private static Exercise exercise(String name, int sets, int reps, String notes, int sortOrder) {
        Exercise ex = new Exercise();
        ex.setName(name);
        ex.setSets(sets);
        ex.setReps(reps);
        ex.setNotes(notes);
        ex.setSortOrder(sortOrder);
        return ex;
    }

    private static String envOrNull(String key) {
        String value = System.getenv(key);
        return value != null && !value.isBlank() ? value : null;
    }
}
