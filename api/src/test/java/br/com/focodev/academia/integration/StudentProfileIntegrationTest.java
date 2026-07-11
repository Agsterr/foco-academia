package br.com.focodev.academia.integration;

import br.com.focodev.academia.integration.support.AcademyFixture;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.JwtService;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class StudentProfileIntegrationTest {

    @Autowired MockMvc mockMvc;
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
    void studentOnboardingAndQuickProgram() throws Exception {
        mockMvc.perform(get("/api/student/profile/status")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingCompleted").value(false));

        mockMvc.perform(post("/api/student/profile/onboarding")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"heightCm":175,"weightKg":80,"goal":"EMAGRECER"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.onboardingCompleted").value(true));

        mockMvc.perform(post("/api/instructor/programs/quick")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"studentId\":\"" + fixture.student().getId() + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Treino rápido — Emagrecimento"));
    }
}
