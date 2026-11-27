package br.com.focodev.academia.integration;

import br.com.focodev.academia.billing.GooglePlayVerifier;
import br.com.focodev.academia.billing.GooglePlayVerifier.VerifiedSubscription;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.integration.support.AcademyFixture;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.SubscriptionRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Assinatura dos alunos com o bloqueio ligado; o Google Play é simulado. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
@TestPropertySource(properties = {
        "app.billing.enforce=true",
        "app.billing.free-emails=liberado@teste.com",
        "app.billing.academy-included-students=1"
})
class BillingIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired AcademyRepository academyRepository;
    @Autowired UserRepository userRepository;
    @Autowired SubscriptionRepository subscriptionRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    @Autowired br.com.focodev.academia.billing.StudentLimit studentLimit;

    @MockitoBean GooglePlayVerifier verifier;

    private String token;
    private UUID userId;

    @BeforeEach
    void setUp() throws Exception {
        when(verifier.isConfigured()).thenReturn(true);
        String email = "pagante-" + UUID.randomUUID().toString().substring(0, 8) + "@teste.com";
        String body = mockMvc.perform(post("/api/auth/register")
                        .header("X-Real-IP", "10.9." + (int) (Math.random() * 250) + "." + (int) (Math.random() * 250))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "name", "Aluno Pagante", "email", email, "password", "segredo123"))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        token = objectMapper.readTree(body).get("token").asText();
        userId = UUID.fromString(objectMapper.readTree(body).get("user").get("id").asText());
    }

    private void expireTrial() {
        var sub = subscriptionRepository.findByUserId(userId).orElseThrow();
        sub.setExpiresAt(Instant.now().minusSeconds(60));
        subscriptionRepository.save(sub);
    }

    @Test
    void newAccountStartsSevenDayTrial() throws Exception {
        mockMvc.perform(get("/api/student/subscription").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.premium").value(true))
                .andExpect(jsonPath("$.reason").value("TRIAL"))
                .andExpect(jsonPath("$.enforced").value(true));
        var sub = subscriptionRepository.findByUserId(userId).orElseThrow();
        long days = Duration.between(Instant.now(), sub.getExpiresAt()).toDays();
        org.assertj.core.api.Assertions.assertThat(days).isBetween(6L, 7L);
    }

    @Test
    void expiredTrialBlocksPremiumFeaturesButNotTheRestOfTheApp() throws Exception {
        expireTrial();

        mockMvc.perform(get("/api/student/subscription").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.premium").value(false))
                .andExpect(jsonPath("$.reason").value("NONE"));
        mockMvc.perform(post("/api/student/templates/musculacao-iniciante/start").header("Authorization", "Bearer " + token))
                .andExpect(status().isPaymentRequired());
        mockMvc.perform(get("/api/student/templates").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
        mockMvc.perform(get("/api/student/stats").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @Test
    void verifiedGooglePlayPurchaseUnlocksPremium() throws Exception {
        expireTrial();
        Instant renewsAt = Instant.now().plus(Duration.ofDays(30));
        when(verifier.verify(eq("foco_academia_mensal"), eq("token-google")))
                .thenReturn(Optional.of(new VerifiedSubscription("foco_academia_mensal", renewsAt, true, true)));

        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"token-google\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.premium").value(true))
                .andExpect(jsonPath("$.reason").value("SUBSCRIPTION"))
                .andExpect(jsonPath("$.autoRenewing").value(true));

        mockMvc.perform(post("/api/student/templates/musculacao-iniciante/start").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());
    }

    @Test
    void rejectsInactiveUnknownOrReusedPurchases() throws Exception {
        when(verifier.verify(anyString(), eq("token-vencido")))
                .thenReturn(Optional.of(new VerifiedSubscription("foco_academia_mensal", Instant.now().minusSeconds(5), false, false)));
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"token-vencido\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"plano_falso\",\"purchaseToken\":\"x\"}"))
                .andExpect(status().isBadRequest());

        // Mesma compra já vinculada a outra conta.
        when(verifier.verify(anyString(), eq("token-de-outro")))
                .thenReturn(Optional.of(new VerifiedSubscription("foco_academia_mensal", Instant.now().plus(Duration.ofDays(365)), true, true)));
        AcademyFixture other = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        User otherStudent = other.student();
        otherStudent.setAcademy(null);
        userRepository.save(otherStudent);
        String otherToken = jwtService.generateToken(new AuthUser(otherStudent));
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + otherToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"token-de-outro\"}"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"token-de-outro\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void purchaseWithoutServerConfigurationIsUnavailable() throws Exception {
        when(verifier.isConfigured()).thenReturn(false);
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"x\"}"))
                .andExpect(status().isServiceUnavailable());
    }

    @Test
    void academyStudentPaysTheLinkedPlanAndLosesTheInstructorPlanWhenItExpires() throws Exception {
        AcademyFixture fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        String bearer = "Bearer " + fixture.studentToken();
        mockMvc.perform(get("/api/student/subscription").header("Authorization", bearer))
                .andExpect(jsonPath("$.reason").value("TRIAL"))
                .andExpect(jsonPath("$.academyStudent").value(true))
                .andExpect(jsonPath("$.productIds[0]").value("foco_academia_aluno_mensal"));
        mockMvc.perform(get("/api/student/workouts").header("Authorization", bearer))
                .andExpect(status().isOk());

        var sub = subscriptionRepository.findByUserId(fixture.student().getId()).orElseThrow();
        sub.setExpiresAt(Instant.now().minusSeconds(60));
        subscriptionRepository.save(sub);

        mockMvc.perform(get("/api/student/workouts").header("Authorization", bearer))
                .andExpect(status().isPaymentRequired());
        mockMvc.perform(get("/api/student/programs/active").header("Authorization", bearer))
                .andExpect(status().isPaymentRequired());
        mockMvc.perform(get("/api/student/stats").header("Authorization", bearer))
                .andExpect(status().isOk());
        // O plano cheio não serve para aluno vinculado.
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", bearer)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_mensal\",\"purchaseToken\":\"x\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void independentStudentCannotBuyTheCheaperLinkedPlan() throws Exception {
        mockMvc.perform(post("/api/student/subscription/google-play")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"productId\":\"foco_academia_aluno_mensal\",\"purchaseToken\":\"x\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void freeListedEmailNeverPays() throws Exception {
        AcademyFixture fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        User student = fixture.student();
        student.setEmail("Liberado@Teste.com");
        userRepository.save(student);
        String bearer = "Bearer " + jwtService.generateToken(new AuthUser(student));

        mockMvc.perform(get("/api/student/subscription").header("Authorization", bearer))
                .andExpect(jsonPath("$.premium").value(true))
                .andExpect(jsonPath("$.reason").value("COURTESY"));
        mockMvc.perform(get("/api/student/workouts").header("Authorization", bearer))
                .andExpect(status().isOk());
    }

    @Test
    void studentLimitBlocksNewStudentsAboveThePlan() {
        AcademyFixture fixture = AcademyFixture.create(academyRepository, userRepository, passwordEncoder, jwtService);
        var academy = fixture.student().getAcademy();
        // Limite de 1 aluno neste teste; a academia do cenário já tem um.
        org.assertj.core.api.Assertions.assertThatThrownBy(() -> studentLimit.requireRoom(academy))
                .isInstanceOf(br.com.focodev.academia.exception.ApiException.class)
                .hasMessageContaining("até 1 alunos");
    }

    @Test
    void adminCanGrantDays() throws Exception {
        expireTrial();
        User admin = new User();
        admin.setEmail("admin-" + UUID.randomUUID().toString().substring(0, 6) + "@teste.com");
        admin.setName("Admin");
        admin.setPasswordHash("x");
        admin.setRole(UserRole.ADMIN);
        admin = userRepository.save(admin);
        String adminToken = jwtService.generateToken(new AuthUser(admin));

        mockMvc.perform(post("/api/admin/users/" + userId + "/subscription/grant")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"days\":30}"))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/api/student/subscription").header("Authorization", "Bearer " + token))
                .andExpect(jsonPath("$.premium").value(true))
                .andExpect(jsonPath("$.reason").value("SUBSCRIPTION"));

        mockMvc.perform(post("/api/admin/users/" + userId + "/subscription/grant")
                        .header("Authorization", "Bearer " + token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"days\":30}"))
                .andExpect(status().isForbidden());
    }
}
