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
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Aluno avulso: conta criada no app, sem academia, com treinos próprios e treinos prontos. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class IndependentStudentIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private String email;

    @BeforeEach
    void setUp() {
        email = "avulso-" + UUID.randomUUID().toString().substring(0, 8) + "@teste.com";
    }

    /** IP diferente a cada chamada para não esbarrar no limite de tentativas de login. */
    private static MockHttpServletRequestBuilder fromNewIp(MockHttpServletRequestBuilder builder) {
        return builder.header("X-Real-IP", "10.0." + (int) (Math.random() * 250) + "." + (int) (Math.random() * 250));
    }

    private String register() throws Exception {
        String body = mockMvc.perform(fromNewIp(post("/api/auth/register"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", "Aluno Avulso",
                                "email", email,
                                "password", "segredo123",
                                "deviceId", "device-" + email,
                                "appClient", "MOBILE"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.role").value("ALUNO"))
                .andExpect(jsonPath("$.user.academyId").doesNotExist())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body).get("token").asText();
    }

    private Map<String, Object> ownProgram(String title) {
        return Map.of(
                "title", title,
                "days", List.of(Map.of(
                        "weekDay", "MONDAY",
                        "muscleGroup", "Peito",
                        "restDay", false,
                        "sortOrder", 1,
                        "exercises", List.of(Map.of("name", "Supino reto", "sets", 3, "reps", 10, "sortOrder", 1))
                ))
        );
    }

    @Test
    void registerCreatesStudentWithoutAcademy_andAppWorks() throws Exception {
        String token = register();

        mockMvc.perform(get("/api/student/stats").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/auth/refresh").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @Test
    void registerRejectsDuplicateEmailAndNonStudentRole() throws Exception {
        register();
        mockMvc.perform(fromNewIp(post("/api/auth/register"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", "Outro", "email", email, "password", "segredo123"))))
                .andExpect(status().isBadRequest());
        mockMvc.perform(fromNewIp(post("/api/auth/register"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", "Instrutor", "email", "x" + email, "password", "segredo123",
                                "role", "INSTRUTOR"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void independentStudentLogsInWithoutAcademyCode() throws Exception {
        register();
        mockMvc.perform(fromNewIp(post("/api/auth/login"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email, "password", "segredo123", "deviceId", "device-" + email))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isString());

        mockMvc.perform(fromNewIp(post("/api/auth/login"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email, "password", "segredo123", "academySlug", "alguma-academia",
                                "deviceId", "device-" + email))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void studentCreatesEditsActivatesAndDeletesOwnPrograms() throws Exception {
        String token = register();

        String first = mockMvc.perform(post("/api/student/programs")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(ownProgram("Meu treino A"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ownedByStudent").value(true))
                .andExpect(jsonPath("$.active").value(true))
                .andReturn().getResponse().getContentAsString();
        String firstId = objectMapper.readTree(first).get("id").asText();

        String second = mockMvc.perform(post("/api/student/programs")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(ownProgram("Meu treino B"))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String secondId = objectMapper.readTree(second).get("id").asText();

        // Só uma ficha ativa por vez: a mais nova.
        mockMvc.perform(get("/api/student/programs/active").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.id").value(secondId));

        mockMvc.perform(post("/api/student/programs/" + firstId + "/activate").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active").value(true));
        mockMvc.perform(get("/api/student/programs/active").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.id").value(firstId));

        // Editar cria nova versão e some com a antiga da lista.
        String edited = mockMvc.perform(put("/api/student/programs/" + firstId)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(ownProgram("Meu treino A editado"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Meu treino A editado"))
                .andExpect(jsonPath("$.active").value(true))
                .andReturn().getResponse().getContentAsString();
        String editedId = objectMapper.readTree(edited).get("id").asText();

        mockMvc.perform(delete("/api/student/programs/" + secondId).header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        JsonNode list = objectMapper.readTree(mockMvc.perform(get("/api/student/programs")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString());
        assertThat(list).hasSize(1);
        assertThat(list.get(0).get("id").asText()).isEqualTo(editedId);
    }

    @Test
    void templatesCoverAllModalitiesAndLevels_andStartCreatesWorkouts() throws Exception {
        String token = register();

        mockMvc.perform(get("/api/student/templates").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(12));
        mockMvc.perform(get("/api/student/templates?modality=SPINNING&level=AVANCADO")
                        .header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].key").value("spinning-avancado"));

        mockMvc.perform(post("/api/student/templates/musculacao-iniciante/start")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kind").value("PROGRAM"))
                .andExpect(jsonPath("$.programId").isString());
        mockMvc.perform(get("/api/student/programs/active").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.templateKey").value("musculacao-iniciante"))
                .andExpect(jsonPath("$.days.length()").value(7));

        mockMvc.perform(post("/api/student/templates/corrida-iniciante/start")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kind").value("CARDIO"));
        mockMvc.perform(get("/api/student/cardio-workouts/active").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Caminhada e corrida — Iniciante"))
                .andExpect(jsonPath("$.intervals.length()").value(18));

        mockMvc.perform(post("/api/student/templates/nao-existe/start").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
    }

    @Test
    void independentStudentCannotSendSuggestions() throws Exception {
        String token = register();
        mockMvc.perform(post("/api/student/suggestions")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"message\":\"Mais aparelhos\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void academyStudentSeesInstructorProgramButCannotEditIt() throws Exception {
        AcademyFixture fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        String instructorProgram = mockMvc.perform(post("/api/instructor/programs")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "title", "Ficha do instrutor",
                                "studentId", fixture.student().getId().toString(),
                                "days", List.of(Map.of("weekDay", "MONDAY", "restDay", false, "sortOrder", 1,
                                        "exercises", List.of(Map.of("name", "Agachamento", "sets", 3, "reps", 10, "sortOrder", 1))))
                        ))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String instructorProgramId = objectMapper.readTree(instructorProgram).get("id").asText();

        mockMvc.perform(get("/api/student/programs").header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(jsonPath("$[0].ownedByStudent").value(false))
                .andExpect(jsonPath("$[0].instructorName").value(fixture.instructor().getName()));

        mockMvc.perform(put("/api/student/programs/" + instructorProgramId)
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(ownProgram("Hack"))))
                .andExpect(status().isBadRequest());

        // O aluno de academia também pode ter fichas próprias e voltar para a do instrutor.
        mockMvc.perform(post("/api/student/programs")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(ownProgram("Extra"))))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/student/programs/" + instructorProgramId + "/activate")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/student/programs/active").header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(jsonPath("$.id").value(instructorProgramId));
    }
}
