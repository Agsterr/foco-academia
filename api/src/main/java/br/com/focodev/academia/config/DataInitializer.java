package br.com.focodev.academia.config;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
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
            }
        };
    }

    private static String envOrNull(String key) {
        String value = System.getenv(key);
        return value != null && !value.isBlank() ? value : null;
    }
}
