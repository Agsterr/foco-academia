package br.com.focodev.academia.integration;

import br.com.focodev.academia.integration.support.AcademyFixture;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.JwtService;
import com.fasterxml.jackson.databind.JsonNode;
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

import java.util.List;
import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class WorkoutSessionIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private AcademyFixture fixture;
    private String mondayDayId;
    private String sundayDayId;
    private String exerciseId;

    @BeforeEach
    void setUp() throws Exception {
        fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        JsonNode program = createProgram();
        mondayDayId = program.get("days").get(0).get("id").asText();
        sundayDayId = program.get("days").get(1).get("id").asText();
        exerciseId = program.get("days").get(0).get("exercises").get(0).get("id").asText();
    }

    @Test
    void studentStartsSession_marksSets_andCompletesWithFeedback() throws Exception {
        String sessionId = startSession(mondayDayId);

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/sets")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "exerciseId", exerciseId,
                                "setNumber", 1
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.setLogs.length()").value(1))
                .andExpect(jsonPath("$.setLogs[0].setNumber").value(1));

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/sets")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "exerciseId", exerciseId,
                                "setNumber", 1
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.setLogs.length()").value(0));

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/sets")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "exerciseId", exerciseId,
                                "setNumber", 1
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.setLogs.length()").value(1));

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/complete")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "rating", "BOM",
                                "comment", "Treino puxado mas consegui!"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").exists())
                .andExpect(jsonPath("$.session.rating").value("BOM"))
                .andExpect(jsonPath("$.session.comment").value("Treino puxado mas consegui!"))
                .andExpect(jsonPath("$.stats.totalWorkoutsCompleted").value(1))
                .andExpect(jsonPath("$.stats.daysCompletedThisWeek").value(1));
    }

    @Test
    void instructorSeesSessionFeedbackAfterStudentCompletes() throws Exception {
        String sessionId = startSession(mondayDayId);

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/complete")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "rating", "MUITO_BOM",
                                "comment", "Adorei o treino de peito"
                        ))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/instructor/session-feedbacks")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].student.name").value(fixture.student().getName()))
                .andExpect(jsonPath("$[0].weekDay").value("MONDAY"))
                .andExpect(jsonPath("$[0].muscleGroup").value("Peito"))
                .andExpect(jsonPath("$[0].rating").value("MUITO_BOM"))
                .andExpect(jsonPath("$[0].comment").value("Adorei o treino de peito"));
    }

    @Test
    void restDayCannotStartSession() throws Exception {
        mockMvc.perform(post("/api/student/days/" + sundayDayId + "/sessions")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Este dia é de descanso"));
    }

    @Test
    void studentStatsEndpoint_returnsMetrics() throws Exception {
        String sessionId = startSession(mondayDayId);
        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/complete")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("rating", "BOM"))))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/student/stats")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalWorkoutsCompleted").value(1))
                .andExpect(jsonPath("$.daysCompletedThisWeek").value(1))
                .andExpect(jsonPath("$.completedWeekDays[0]").value("MONDAY"));
    }

    @Test
    void invalidSetNumber_isRejected() throws Exception {
        String sessionId = startSession(mondayDayId);

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/sets")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "exerciseId", exerciseId,
                                "setNumber", 99
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Série inválida"));
    }

    @Test
    void completedSessionCannotToggleSets() throws Exception {
        String sessionId = startSession(mondayDayId);

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/complete")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("rating", "BOM"))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/student/sessions/" + sessionId + "/sets")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "exerciseId", exerciseId,
                                "setNumber", 1
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Treino já finalizado"));
    }

    private String startSession(String dayId) throws Exception {
        String response = mockMvc.perform(post("/api/student/days/" + dayId + "/sessions")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.workoutDayId").value(dayId))
                .andReturn()
                .getResponse()
                .getContentAsString();
        return objectMapper.readTree(response).get("id").asText();
    }

    private JsonNode createProgram() throws Exception {
        Map<String, Object> body = Map.of(
                "title", "Ficha Sessão",
                "studentId", fixture.student().getId().toString(),
                "days", List.of(
                        Map.of(
                                "weekDay", "MONDAY",
                                "muscleGroup", "Peito",
                                "restDay", false,
                                "sortOrder", 0,
                                "exercises", List.of(Map.of(
                                        "name", "Supino",
                                        "sets", 3,
                                        "reps", 10,
                                        "sortOrder", 0
                                ))
                        ),
                        Map.of(
                                "weekDay", "SUNDAY",
                                "restDay", true,
                                "sortOrder", 1,
                                "exercises", List.of()
                        )
                )
        );

        String response = mockMvc.perform(post("/api/instructor/programs")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return objectMapper.readTree(response);
    }
}
