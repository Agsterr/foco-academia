package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.repository.WorkoutRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class StudentWorkoutsIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired WorkoutRepository workoutRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private String studentToken;
    private String academySlug;
    private UUID studentId;

    @BeforeEach
    void setUp() {
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        academySlug = "academia-treinos-" + suffix;
        Academy academy = new Academy();
        academy.setName("Academia Treinos");
        academy.setSlug(academySlug);
        academy.setDeviceLimitPerUser(3);
        academyRepository.saveAndFlush(academy);

        User instructor = new User();
        instructor.setEmail("instrutor-" + suffix + "@test.com");
        instructor.setName("Instrutor Treinos");
        instructor.setPasswordHash(passwordEncoder.encode("senha123"));
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        userRepository.saveAndFlush(instructor);

        User student = new User();
        student.setEmail("aluno-" + suffix + "@test.com");
        student.setName("Aluno Treinos");
        student.setPasswordHash(passwordEncoder.encode("senha123"));
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setInstructor(instructor);
        userRepository.saveAndFlush(student);
        studentId = student.getId();

        Workout workout = new Workout();
        workout.setTitle("Treino de teste");
        workout.setDescription("Peito e tríceps");
        workout.setInstructor(instructor);
        workout.setStudent(student);
        workout.setStatus(WorkoutStatus.ATIVO);

        Exercise exercise = new Exercise();
        exercise.setWorkout(workout);
        exercise.setName("Supino");
        exercise.setSets(4);
        exercise.setReps(10);
        exercise.setSortOrder(0);
        workout.getExercises().add(exercise);
        workoutRepository.saveAndFlush(workout);

        studentToken = jwtService.generateToken(new AuthUser(student));    }

    @Test
    void listStudentWorkouts_returnsWorkoutWithExercises() throws Exception {
        mockMvc.perform(get("/api/student/workouts")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").value("Treino de teste"))
                .andExpect(jsonPath("$[0].student.name").value("Aluno Treinos"))
                .andExpect(jsonPath("$[0].student.academySlug").value(academySlug))
                .andExpect(jsonPath("$[0].exercises[0].name").value("Supino"));
    }
}
