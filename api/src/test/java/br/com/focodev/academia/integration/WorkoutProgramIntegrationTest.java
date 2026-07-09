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
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class WorkoutProgramIntegrationTest {

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
    void instructorCreatesWeeklyProgram_andStudentViewsIt() throws Exception {
        String programId = createSampleProgram();

        mockMvc.perform(get("/api/student/programs/active")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(programId))
                .andExpect(jsonPath("$.title").value("Ficha Semanal Teste"))
                .andExpect(jsonPath("$.days.length()").value(2))
                .andExpect(jsonPath("$.days[0].weekDay").value("MONDAY"))
                .andExpect(jsonPath("$.days[0].muscleGroup").value("Peito e Tríceps"))
                .andExpect(jsonPath("$.days[0].exercises[0].name").value("Supino reto"))
                .andExpect(jsonPath("$.days[1].restDay").value(true));
    }

    @Test
    void instructorListsPrograms() throws Exception {
        createSampleProgram();

        mockMvc.perform(get("/api/instructor/programs")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].title").value("Ficha Semanal Teste"))
                .andExpect(jsonPath("$[0].student.name").value(fixture.student().getName()));
    }

    @Test
    void newProgramDeactivatesPreviousOne() throws Exception {
        createSampleProgram();

        Map<String, Object> body = Map.of(
                "title", "Ficha Nova",
                "studentId", fixture.student().getId().toString(),
                "days", List.of(Map.of(
                        "weekDay", "TUESDAY",
                        "muscleGroup", "Costas",
                        "restDay", false,
                        "sortOrder", 0,
                        "exercises", List.of(Map.of(
                                "name", "Remada",
                                "sets", 3,
                                "reps", 12,
                                "sortOrder", 0
                        ))
                ))
        );

        mockMvc.perform(post("/api/instructor/programs")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/student/programs/active")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Ficha Nova"));
    }

    @Test
    void studentCannotAccessAnotherStudentsProgram() throws Exception {
        String programId = createSampleProgram();

        AcademyFixture other = AcademyFixture.create(
                academyRepository, userRepository, passwordEncoder, jwtService);

        mockMvc.perform(get("/api/student/programs/" + programId)
                        .header("Authorization", "Bearer " + other.studentToken()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Acesso negado"));
    }

    private String createSampleProgram() throws Exception {
        Map<String, Object> body = Map.of(
                "title", "Ficha Semanal Teste",
                "description", "Programa de teste",
                "studentId", fixture.student().getId().toString(),
                "days", List.of(
                        Map.of(
                                "weekDay", "MONDAY",
                                "muscleGroup", "Peito e Tríceps",
                                "restDay", false,
                                "sortOrder", 0,
                                "exercises", List.of(Map.of(
                                        "name", "Supino reto",
                                        "sets", 3,
                                        "reps", 10,
                                        "variationNotes", "Pegada média",
                                        "sortOrder", 0
                                ))
                        ),
                        Map.of(
                                "weekDay", "SUNDAY",
                                "muscleGroup", "Descanso",
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
                .andExpect(jsonPath("$.title").value("Ficha Semanal Teste"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        return objectMapper.readTree(response).get("id").asText();
    }
}
