package br.com.focodev.academia.config;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.repository.WorkoutRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@RequiredArgsConstructor
public class DataInitializer {

    private final UserRepository userRepository;
    private final WorkoutRepository workoutRepository;
    private final PasswordEncoder passwordEncoder;

    @Bean
    CommandLineRunner seedDemoUsers() {
        return args -> {
            if (userRepository.count() > 0) {
                return;
            }

            User instructor = new User();
            instructor.setEmail("instrutor@academia.com");
            instructor.setPasswordHash(passwordEncoder.encode("instrutor123"));
            instructor.setName("Instrutor Demo");
            instructor.setRole(UserRole.INSTRUTOR);
            userRepository.save(instructor);

            User student = new User();
            student.setEmail("aluno@academia.com");
            student.setPasswordHash(passwordEncoder.encode("aluno123"));
            student.setName("Aluno Demo");
            student.setRole(UserRole.ALUNO);
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
        };
    }
}
