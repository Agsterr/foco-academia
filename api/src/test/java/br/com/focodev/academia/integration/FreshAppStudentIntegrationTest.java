package br.com.focodev.academia.integration;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Conta recém-criada pelo app (sem perfil, sem ficha, sem histórico) chamando tudo que o app abre. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class FreshAppStudentIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;

    /** Telas e ações abertas por uma conta nova do app: nada pode dar erro de servidor nem pedir onboarding. */
    @Test
    void freshAppAccountCanUseEverythingTheAppOpens() throws Exception {
        String email = "novo-" + UUID.randomUUID().toString().substring(0, 8) + "@teste.com";
        String body = mockMvc.perform(post("/api/auth/register")
                        .header("X-Real-IP", "10.9." + (int) (Math.random() * 250) + "." + (int) (Math.random() * 250))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", "Aluno Novo", "email", email, "password", "segredo123",
                                "deviceId", "dev-" + email, "appClient", "MOBILE"))))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        String token = objectMapper.readTree(body).get("token").asText();
        String auth = "Bearer " + token;

        // Leituras que o app faz ao abrir cada tela. Só estes retornos "não encontrado" são esperados,
        // e o app trata os três: perfil vazio, "sem treino ativo" e 404 como "nenhum treino outdoor".
        Map<String, Integer> expectedStatus = new LinkedHashMap<>();
        for (String p : new String[]{
                "/api/auth/me", "/api/student/programs", "/api/student/templates", "/api/student/subscription",
                "/api/student/stats", "/api/student/workouts", "/api/student/suggestions",
                "/api/student/profile/status", "/api/student/calorie-stats", "/api/student/dashboard",
                "/api/student/measurements", "/api/student/cardio-workouts", "/api/student/cardio-sessions",
                "/api/student/gps-config", "/api/student/ai/recommendations"}) {
            expectedStatus.put(p, 200);
        }
        expectedStatus.put("/api/student/profile", 400);
        expectedStatus.put("/api/student/programs/active", 400);
        expectedStatus.put("/api/student/cardio-workouts/active", 404);
        for (var e : expectedStatus.entrySet()) {
            mockMvc.perform(get(e.getKey()).header("Authorization", auth))
                    .andExpect(status().is(e.getValue()));
        }

        // Ações: registrar o peso e iniciar um treino pronto funcionam sem perfil.
        mockMvc.perform(post("/api/student/measurements")
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"weightKg\":72.5}"))
                .andExpect(status().isOk());

        String templates = mockMvc.perform(get("/api/student/templates").header("Authorization", auth))
                .andReturn().getResponse().getContentAsString();
        String key = objectMapper.readTree(templates).get(0).get("key").asText();
        mockMvc.perform(post("/api/student/templates/" + key + "/start")
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
    }
}
