package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.integration.support.AcademyFixture;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.repository.WorkoutRepository;
import br.com.focodev.academia.security.JwtService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class LegacyWorkoutFeedbackIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired WorkoutRepository workoutRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private AcademyFixture fixture;
    private String workoutId;

    @BeforeEach
    void setUp() {
        fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);

        Workout workout = new Workout();
        workout.setTitle("Treino Legado");
        workout.setInstructor(fixture.instructor());
        workout.setStudent(fixture.student());
        workout.setStatus(WorkoutStatus.ATIVO);

        Exercise exercise = new Exercise();
        exercise.setWorkout(workout);
        exercise.setName("Agachamento");
        exercise.setSets(4);
        exercise.setReps(8);
        exercise.setSortOrder(0);
        workout.getExercises().add(exercise);
        workoutRepository.saveAndFlush(workout);
        workoutId = workout.getId().toString();
    }

    @Test
    void studentSubmitsLegacyFeedback_andInstructorSeesIt() throws Exception {
        mockMvc.perform(post("/api/student/workouts/" + workoutId + "/feedback")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "rating", "BOM",
                                "comment", "Treino antigo ainda funciona",
                                "completed", true
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rating").value("BOM"))
                .andExpect(jsonPath("$.completed").value(true));

        mockMvc.perform(get("/api/instructor/feedbacks")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].student.name").value(fixture.student().getName()))
                .andExpect(jsonPath("$[0].comment").value("Treino antigo ainda funciona"))
                .andExpect(jsonPath("$[0].completed").value(true));

        mockMvc.perform(get("/api/student/workouts/" + workoutId)
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CONCLUIDO"));
    }
}
