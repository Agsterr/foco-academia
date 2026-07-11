package br.com.focodev.academia.integration;

import br.com.focodev.academia.integration.support.AcademyFixture;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
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

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class CardioIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private AcademyFixture fixture;

    @BeforeEach
    void setUp() {
        fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
    }

    @Test
    void instructorCreatesCardioWorkout_studentStartsAndCompletes() throws Exception {
        Map<String, Object> workoutBody = Map.of(
                "studentId", fixture.student().getId().toString(),
                "title", "Caminhada intervalada",
                "type", "INTERVAL",
                "intervals", List.of(
                        Map.of("phase", "WALK", "durationSec", 120),
                        Map.of("phase", "RUN", "durationSec", 60)
                )
        );

        String workoutJson = mockMvc.perform(post("/api/instructor/cardio-workouts")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(workoutBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Caminhada intervalada"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        UUID workoutId = UUID.fromString(
                workoutJson.replaceAll("(?s).*\"id\"\\s*:\\s*\"([^\"]+)\".*", "$1"));

        mockMvc.perform(get("/api/student/cardio-workouts/active")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(workoutId.toString()));

        String sessionJson = mockMvc.perform(post("/api/student/cardio-sessions/start")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"workoutId\":\"" + workoutId + "\",\"clientSessionId\":\"test-session-1\"}"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        UUID sessionId = UUID.fromString(
                sessionJson.replaceAll("(?s).*\"id\"\\s*:\\s*\"([^\"]+)\".*", "$1"));

        Map<String, Object> completeBody = Map.of(
                "distanceMeters", 2500.0,
                "avgSpeedKmh", 8.5,
                "elapsedMs", 1200000,
                "pausedMs", 180000,
                "pauseCount", 2,
                "points", List.of(
                        Map.of("latitude", -23.5, "longitude", -46.6, "speedKmh", 8.0,
                                "recordedAt", "2026-01-01T12:00:00Z", "sequenceNum", 0),
                        Map.of("latitude", -23.51, "longitude", -46.61, "speedKmh", 9.0,
                                "recordedAt", "2026-01-01T12:05:00Z", "sequenceNum", 1)
                )
        );

        mockMvc.perform(post("/api/student/cardio-sessions/" + sessionId + "/complete")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(completeBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.distanceMeters").value(2500.0))
                .andExpect(jsonPath("$.elapsedMs").value(1200000))
                .andExpect(jsonPath("$.pausedMs").value(180000))
                .andExpect(jsonPath("$.pauseCount").value(2));

        mockMvc.perform(get("/api/instructor/cardio-stats")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sessionsThisWeek").value(1));
    }

    @Test
    void instructorCanUpdateAndDeleteCardioWorkout() throws Exception {
        Map<String, Object> workoutBody = Map.of(
                "studentId", fixture.student().getId().toString(),
                "title", "Caminhada intervalada",
                "type", "INTERVAL",
                "intervals", List.of(
                        Map.of("phase", "WALK", "durationSec", 120),
                        Map.of("phase", "RUN", "durationSec", 60)
                )
        );

        String workoutJson = mockMvc.perform(post("/api/instructor/cardio-workouts")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(workoutBody)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        UUID workoutId = UUID.fromString(
                workoutJson.replaceAll("(?s).*\"id\"\\s*:\\s*\"([^\"]+)\".*", "$1"));

        Map<String, Object> updateBody = Map.of(
                "title", "Intervalado atualizado",
                "type", "INTERVAL",
                "intervals", List.of(
                        Map.of("phase", "WALK", "durationSec", 90),
                        Map.of("phase", "RUN", "durationSec", 90)
                ),
                "active", true
        );

        mockMvc.perform(put("/api/instructor/cardio-workouts/" + workoutId)
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateBody)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Intervalado atualizado"))
                .andExpect(jsonPath("$.active").value(true));

        mockMvc.perform(get("/api/student/cardio-workouts/active")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Intervalado atualizado"));

        mockMvc.perform(delete("/api/instructor/cardio-workouts/" + workoutId)
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/instructor/cardio-workouts")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isEmpty());
    }
}
