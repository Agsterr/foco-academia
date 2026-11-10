package br.com.focodev.academia.integration;

import br.com.focodev.academia.repository.DeviceSessionRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Convite por link: uso único, conta já ligada à academia e ao instrutor, e um aparelho por vez. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class InviteIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired DeviceSessionRepository deviceSessionRepository;

    private static MockHttpServletRequestBuilder fromNewIp(MockHttpServletRequestBuilder builder) {
        return builder.header("X-Real-IP", "10.8." + (int) (Math.random() * 250) + "." + (int) (Math.random() * 250));
    }

    private static String email(String prefix) {
        return prefix + "-" + UUID.randomUUID().toString().substring(0, 8) + "@teste.com";
    }

    private JsonNode json(String body) throws Exception {
        return objectMapper.readTree(body);
    }

    private ResultActions postAs(String token, String url, Object body) throws Exception {
        var request = fromNewIp(post(url)).contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body));
        if (token != null) request.header("Authorization", "Bearer " + token);
        return mockMvc.perform(request);
    }

    private JsonNode ok(ResultActions actions) throws Exception {
        String body = actions.andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return body.isEmpty() ? null : json(body);
    }

    private JsonNode registerBusiness(String type, String academyName) throws Exception {
        Map<String, Object> body = new HashMap<>(Map.of(
                "type", type, "name", "Dono Silva", "email", email("dono"), "password", "segredo123"));
        if (academyName != null) body.put("academyName", academyName);
        return ok(postAs(null, "/api/auth/register-business", body));
    }

    private JsonNode invite(String token, String role, Map<String, Object> extra) throws Exception {
        Map<String, Object> body = new HashMap<>(extra);
        body.put("role", role);
        return ok(postAs(token, "/api/manager/invites", body));
    }

    private ResultActions accept(String code, String email, String device) throws Exception {
        return postAs(null, "/api/auth/invites/" + code + "/accept", Map.of(
                "name", "Pessoa Convidada", "email", email, "password", "segredo123",
                "deviceId", device, "deviceLabel", "Flutter Android", "appClient", "MOBILE"));
    }

    private ResultActions login(String email, String device) throws Exception {
        return postAs(null, "/api/auth/login", Map.of(
                "email", email, "password", "segredo123", "deviceId", device, "deviceLabel", "Flutter Android"));
    }

    @Test
    void personalInvitesStudent_linkWorksOnceAndAccountIsReady() throws Exception {
        JsonNode personal = registerBusiness("INSTRUTOR_AUTONOMO", null);
        String token = personal.get("token").asText();

        JsonNode created = invite(token, "ALUNO", Map.of("name", "Bruno Lima"));
        String code = created.get("code").asText();
        assertThat(code).hasSize(10).matches("[A-Z2-9]+");
        assertThat(created.get("url").asText()).endsWith("/convite/" + code);
        assertThat(created.get("shareText").asText()).contains("Oi, Bruno!").contains("Dono Silva").contains(code.substring(0, 5) + "-");

        // Quem abre o link vê quem convidou (o código pode vir minúsculo e com hífen).
        mockMvc.perform(fromNewIp(get("/api/auth/invites/" + code.substring(0, 5).toLowerCase() + "-" + code.substring(5))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("ALUNO"))
                .andExpect(jsonPath("$.instructorName").value("Dono Silva"))
                .andExpect(jsonPath("$.personal").value(true))
                .andExpect(jsonPath("$.name").value("Bruno Lima"));

        String studentEmail = email("aluno");
        JsonNode accepted = ok(accept(code, studentEmail, "celular-1"));
        assertThat(accepted.get("user").get("role").asText()).isEqualTo("ALUNO");
        assertThat(accepted.get("user").get("instructorId").asText()).isEqualTo(personal.get("user").get("id").asText());
        assertThat(accepted.get("academySlug").asText()).isEqualTo(personal.get("academySlug").asText());

        // Já configurado: o aluno aparece para o personal e vê as próprias telas.
        mockMvc.perform(get("/api/instructor/students/overview").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$[0].email").value(studentEmail));
        mockMvc.perform(get("/api/student/subscription")
                        .header("Authorization", "Bearer " + accepted.get("token").asText()))
                .andExpect(status().isOk());

        // O mesmo link em outro celular não serve mais.
        accept(code, email("outro"), "celular-2")
                .andExpect(status().isGone())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("já foi usado")));
        // Convite usado some da lista de pendentes.
        mockMvc.perform(get("/api/manager/invites").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void invitedAccountStaysOnOneDevice_untilInstructorReleases() throws Exception {
        JsonNode personal = registerBusiness("INSTRUTOR_AUTONOMO", null);
        String token = personal.get("token").asText();
        String studentEmail = email("aluno");
        JsonNode accepted = ok(accept(invite(token, "ALUNO", Map.of()).get("code").asText(), studentEmail, "celular-1"));
        String studentId = accepted.get("user").get("id").asText();

        // Sem código da academia; reinstalar no mesmo celular (mesmo identificador) entra normal.
        ok(login(studentEmail, "celular-1"));
        // Outro celular é barrado enquanto o primeiro está em uso.
        login(studentEmail, "celular-2")
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("outro aparelho")));

        // O personal libera (trocou de celular) e o novo passa a ser o aparelho do aluno.
        postAs(token, "/api/manager/members/" + studentId + "/devices/release", Map.of()).andExpect(status().isNoContent());
        ok(login(studentEmail, "celular-2"));
        login(studentEmail, "celular-1").andExpect(status().isForbidden());

        // Aparelho parado há mais de 7 dias libera a vaga sozinho.
        deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(UUID.fromString(studentId))
                .forEach(s -> {
                    s.setLastSeenAt(Instant.now().minus(Duration.ofDays(8)));
                    deviceSessionRepository.save(s);
                });
        ok(login(studentEmail, "celular-1"));
    }

    @Test
    void academyInvitesInstructor_andInstructorInvitesOwnStudents() throws Exception {
        JsonNode academy = registerBusiness("ACADEMIA", "Academia Convite");
        String manager = academy.get("token").asText();

        JsonNode instructorInvite = invite(manager, "INSTRUTOR", Map.of("name", "Ana"));
        assertThat(instructorInvite.get("shareText").asText()).contains("instrutor(a) na Academia Convite");
        String instructorEmail = email("instrutora");
        JsonNode instructor = ok(accept(instructorInvite.get("code").asText(), instructorEmail, "cel-ana"));
        assertThat(instructor.get("user").get("role").asText()).isEqualTo("INSTRUTOR");
        String instructorToken = instructor.get("token").asText();

        // Instrutora da academia: não convida instrutor, mas convida aluno para ela mesma.
        postAs(instructorToken, "/api/manager/invites", Map.of("role", "INSTRUTOR")).andExpect(status().isForbidden());
        JsonNode studentInvite = invite(instructorToken, "ALUNO", Map.of());
        assertThat(studentInvite.get("instructorName").asText()).isEqualTo("Pessoa Convidada");
        JsonNode student = ok(accept(studentInvite.get("code").asText(), email("aluno"), "cel-aluno"));
        assertThat(student.get("user").get("instructorId").asText()).isEqualTo(instructor.get("user").get("id").asText());

        // O gestor também convida aluno já escolhendo a instrutora, e vê todos os pendentes.
        JsonNode managerInvite = invite(manager, "ALUNO", Map.of("instructorId", instructor.get("user").get("id").asText()));
        assertThat(managerInvite.get("instructorName").asText()).isEqualTo("Pessoa Convidada");
        mockMvc.perform(get("/api/manager/invites").header("Authorization", "Bearer " + manager))
                .andExpect(jsonPath("$.length()").value(1));
        // A instrutora não vê nem cancela o convite do gestor.
        mockMvc.perform(get("/api/manager/invites").header("Authorization", "Bearer " + instructorToken))
                .andExpect(jsonPath("$.length()").value(0));
        mockMvc.perform(delete("/api/manager/invites/" + managerInvite.get("id").asText())
                        .header("Authorization", "Bearer " + instructorToken))
                .andExpect(status().isBadRequest());

        // Convite cancelado não abre mais.
        mockMvc.perform(delete("/api/manager/invites/" + managerInvite.get("id").asText())
                        .header("Authorization", "Bearer " + manager))
                .andExpect(status().isNoContent());
        mockMvc.perform(fromNewIp(get("/api/auth/invites/" + managerInvite.get("code").asText())))
                .andExpect(status().isGone());

        // Outra academia não libera aparelho de quem não é dela.
        String other = registerBusiness("ACADEMIA", "Outra").get("token").asText();
        postAs(other, "/api/manager/members/" + student.get("user").get("id").asText() + "/devices/release", Map.of())
                .andExpect(status().isBadRequest());
    }

    @Test
    void independentStudentLinksExistingAccount_withPassword() throws Exception {
        String studentEmail = email("avulso");
        ok(postAs(null, "/api/auth/register", Map.of(
                "name", "Carla Avulsa", "email", studentEmail, "password", "segredo123",
                "role", "ALUNO", "deviceId", "cel-velho")));

        JsonNode personal = registerBusiness("INSTRUTOR_AUTONOMO", null);
        String code = invite(personal.get("token").asText(), "ALUNO", Map.of()).get("code").asText();

        postAs(null, "/api/auth/invites/" + code + "/accept", Map.of(
                "email", studentEmail, "password", "senha-errada", "deviceId", "cel-novo"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("senha")));

        JsonNode linked = ok(accept(code, studentEmail, "cel-novo"));
        assertThat(linked.get("linkedExistingAccount").asBoolean()).isTrue();
        assertThat(linked.get("user").get("name").asText()).isEqualTo("Carla Avulsa");
        assertThat(linked.get("user").get("instructorId").asText()).isEqualTo(personal.get("user").get("id").asText());
        // A conta passou a valer só no aparelho em que aceitou.
        login(studentEmail, "cel-velho").andExpect(status().isForbidden());
    }

    @Test
    void unknownCodeIsNotFound_andStudentCannotInvite() throws Exception {
        mockMvc.perform(fromNewIp(get("/api/auth/invites/NAOEXISTE1"))).andExpect(status().isNotFound());

        String student = ok(postAs(null, "/api/auth/register", Map.of(
                "name", "Aluno", "email", email("a"), "password", "segredo123", "role", "ALUNO", "deviceId", "x")))
                .get("token").asText();
        postAs(student, "/api/manager/invites", Map.of("role", "ALUNO")).andExpect(status().isForbidden());
    }
}
