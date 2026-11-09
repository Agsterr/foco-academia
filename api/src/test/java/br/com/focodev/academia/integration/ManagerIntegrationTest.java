package br.com.focodev.academia.integration;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Etapa 2: academia e instrutor autônomo se cadastram e acompanham alunos, notas e reclamações. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class ManagerIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;

    private static MockHttpServletRequestBuilder fromNewIp(MockHttpServletRequestBuilder builder) {
        return builder.header("X-Real-IP", "10.7." + (int) (Math.random() * 250) + "." + (int) (Math.random() * 250));
    }

    private static String email(String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().substring(0, 8) + "@teste.com";
    }

    private JsonNode json(String body) throws Exception {
        return objectMapper.readTree(body);
    }

    private JsonNode registerBusiness(String type, String academyName) throws Exception {
        Map<String, Object> body = new HashMap<>(Map.of(
                "type", type, "name", "Fulano Dono", "email", email("dono"), "password", "segredo123"));
        if (academyName != null) body.put("academyName", academyName);
        return json(mockMvc.perform(fromNewIp(post("/api/auth/register-business"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString());
    }

    private JsonNode postJson(String url, String token, Object body) throws Exception {
        String response = mockMvc.perform(post(url)
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return response.isEmpty() ? null : json(response);
    }

    private String login(String email) throws Exception {
        return json(mockMvc.perform(fromNewIp(post("/api/auth/login"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of("email", email, "password", "segredo123", "deviceId", "device-" + email))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString()).get("token").asText();
    }

    private String loginWithSlug(String email, String slug) throws Exception {
        return json(mockMvc.perform(fromNewIp(post("/api/auth/login"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "email", email, "password", "segredo123", "academySlug", slug, "deviceId", "device-" + email))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString()).get("token").asText();
    }

    @Test
    void academyRegistersAsManager_andLogsInWithoutCode() throws Exception {
        JsonNode reg = registerBusiness("ACADEMIA", "Academia Força Total");
        assertThat(reg.get("user").get("role").asText()).isEqualTo("GESTOR");
        assertThat(reg.get("academySlug").asText()).startsWith("academia-forca-total");

        String token = login(reg.get("user").get("email").asText());
        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.academyName").value("Academia Força Total"))
                .andExpect(jsonPath("$.personal").value(false))
                .andExpect(jsonPath("$.planMonthlyPrice").value(149.0))
                .andExpect(jsonPath("$.months.length()").value(6))
                .andExpect(jsonPath("$.students").value(0));
    }

    @Test
    void academyNameIsRequired() throws Exception {
        mockMvc.perform(fromNewIp(post("/api/auth/register-business"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "type", "ACADEMIA", "name", "Dono", "email", email("x"), "password", "segredo123"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void fullFlow_managerSeesPerformanceRatingsAndComplaints() throws Exception {
        JsonNode reg = registerBusiness("ACADEMIA", "Academia Painel");
        String manager = reg.get("token").asText();
        String slug = reg.get("academySlug").asText();

        String instructorEmail = email("instrutor");
        String instructorId = postJson("/api/manager/instructors", manager, Map.of(
                "name", "Ana Instrutora", "email", instructorEmail, "password", "segredo123")).get("id").asText();
        String studentEmail = email("aluno");
        JsonNode student = postJson("/api/manager/students", manager, Map.of(
                "name", "Bruno Aluno", "email", studentEmail, "password", "segredo123", "instructorId", instructorId));
        assertThat(student.get("instructorName").asText()).isEqualTo("Ana Instrutora");

        // Instrutora monta a ficha; aluno treina e dá nota "BOM" (4).
        String instructorToken = loginWithSlug(instructorEmail, slug);
        JsonNode day = postJson("/api/instructor/programs", instructorToken, Map.of(
                "title", "Ficha", "studentId", student.get("id").asText(),
                "days", List.of(Map.of("weekDay", "MONDAY", "restDay", false, "sortOrder", 1,
                        "exercises", List.of(Map.of("name", "Supino", "sets", 3, "reps", 10, "sortOrder", 1))))))
                .get("days").get(0);
        String dayId = day.get("id").asText();
        String exerciseId = day.get("exercises").get(0).get("id").asText();
        String studentToken = loginWithSlug(studentEmail, slug);
        String sessionId = postJson("/api/student/days/" + dayId + "/sessions", studentToken, Map.of()).get("id").asText();
        postJson("/api/student/sessions/" + sessionId + "/sets", studentToken,
                Map.of("exerciseId", exerciseId, "setNumber", 1));
        postJson("/api/student/sessions/" + sessionId + "/complete", studentToken,
                Map.of("rating", "BOM", "comment", "Gostei"));
        postJson("/api/student/suggestions", studentToken, Map.of("message", "Ar-condicionado quebrado", "category", "Reclamação"));

        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + manager))
                .andExpect(jsonPath("$.instructors").value(1))
                .andExpect(jsonPath("$.students").value(1))
                .andExpect(jsonPath("$.activeStudents7d").value(1))
                .andExpect(jsonPath("$.sessions30d").value(1))
                .andExpect(jsonPath("$.averageRating30d").value(4.0))
                .andExpect(jsonPath("$.pendingSuggestions").value(1))
                .andExpect(jsonPath("$.ratingDistribution.BOM").value(1))
                .andExpect(jsonPath("$.months[5].sessions").value(1))
                .andExpect(jsonPath("$.instructorRanking[0].name").value("Ana Instrutora"))
                .andExpect(jsonPath("$.instructorRanking[0].sessions30d").value(1))
                .andExpect(jsonPath("$.instructorRanking[0].pendingSuggestions").value(1));

        mockMvc.perform(get("/api/manager/ratings").header("Authorization", "Bearer " + manager))
                .andExpect(jsonPath("$[0].studentName").value("Bruno Aluno"))
                .andExpect(jsonPath("$[0].score").value(4))
                .andExpect(jsonPath("$[0].comment").value("Gostei"));

        JsonNode suggestions = json(mockMvc.perform(get("/api/manager/suggestions").header("Authorization", "Bearer " + manager))
                .andReturn().getResponse().getContentAsString());
        assertThat(suggestions.get(0).get("message").asText()).isEqualTo("Ar-condicionado quebrado");
        postJson("/api/manager/suggestions/" + suggestions.get(0).get("id").asText() + "/respond", manager,
                Map.of("response", "Técnico chamado para amanhã."));
        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + manager))
                .andExpect(jsonPath("$.pendingSuggestions").value(0));

        mockMvc.perform(get("/api/manager/access").header("Authorization", "Bearer " + manager))
                .andExpect(jsonPath("$.manager").value(true))
                .andExpect(jsonPath("$.personal").value(false));
        mockMvc.perform(get("/api/manager/access").header("Authorization", "Bearer " + instructorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.manager").value(false))
                .andExpect(jsonPath("$.academyName").value("Academia Painel"));

        // A instrutora não vê o painel da academia, só os próprios alunos.
        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + instructorToken))
                .andExpect(status().isForbidden());
        mockMvc.perform(get("/api/instructor/students/overview").header("Authorization", "Bearer " + instructorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].name").value("Bruno Aluno"))
                .andExpect(jsonPath("$[0].sessions30d").value(1))
                .andExpect(jsonPath("$[0].lastActivityAt").isString());
    }

    @Test
    void autonomousInstructorSeesEverythingLikeAnAcademy() throws Exception {
        JsonNode reg = registerBusiness("INSTRUTOR_AUTONOMO", null);
        assertThat(reg.get("user").get("role").asText()).isEqualTo("INSTRUTOR");
        String token = login(reg.get("user").get("email").asText());

        JsonNode student = postJson("/api/manager/students", token, Map.of(
                "name", "Cliente do Personal", "email", email("cliente"), "password", "segredo123"));
        // Sem escolher instrutor, o aluno fica com o próprio personal.
        assertThat(student.get("instructorName").asText()).isEqualTo("Fulano Dono");

        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.personal").value(true))
                .andExpect(jsonPath("$.instructors").value(1))
                .andExpect(jsonPath("$.students").value(1));
        mockMvc.perform(get("/api/manager/access").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.manager").value(true))
                .andExpect(jsonPath("$.personal").value(true));
        // Ele também usa as telas de instrutor.
        mockMvc.perform(get("/api/instructor/students/overview").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$[0].name").value("Cliente do Personal"));
    }

    @Test
    void managerCannotTouchAnotherAcademy_orDeactivateThemselves() throws Exception {
        JsonNode a = registerBusiness("ACADEMIA", "Academia A");
        JsonNode b = registerBusiness("ACADEMIA", "Academia B");
        String studentInB = postJson("/api/manager/students", b.get("token").asText(), Map.of(
                "name", "Aluno B", "email", email("b"), "password", "segredo123")).get("id").asText();
        String instructorInA = postJson("/api/manager/instructors", a.get("token").asText(), Map.of(
                "name", "Instrutor A", "email", email("ia"), "password", "segredo123")).get("id").asText();

        mockMvc.perform(put("/api/manager/students/" + studentInB + "/instructor")
                        .header("Authorization", "Bearer " + a.get("token").asText())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"instructorId\":\"" + instructorInA + "\"}"))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/manager/members/" + studentInB + "/active?value=false")
                        .header("Authorization", "Bearer " + a.get("token").asText()))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/manager/members/" + a.get("user").get("id").asText() + "/active?value=false")
                        .header("Authorization", "Bearer " + a.get("token").asText()))
                .andExpect(status().isBadRequest());
    }

    @Test
    void studentCannotUseManagerEndpoints() throws Exception {
        JsonNode reg = registerBusiness("ACADEMIA", "Academia C");
        String studentEmail = email("aluno-c");
        postJson("/api/manager/students", reg.get("token").asText(), Map.of(
                "name", "Aluno C", "email", studentEmail, "password", "segredo123"));
        String studentToken = loginWithSlug(studentEmail, reg.get("academySlug").asText());
        mockMvc.perform(get("/api/manager/dashboard").header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isForbidden());
    }
}
