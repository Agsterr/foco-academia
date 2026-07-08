package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.JwtService;
import br.com.focodev.academia.security.AuthUser;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AdminAcademyIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private String adminToken;

    @BeforeEach
    void setUp() {
        User admin = new User();
        admin.setEmail("admin-integration@test.com");
        admin.setName("Admin Teste");
        admin.setPasswordHash(passwordEncoder.encode("admin123"));
        admin.setRole(UserRole.ADMIN);
        userRepository.save(admin);
        adminToken = jwtService.generateToken(new AuthUser(admin));
    }

    @Test
    void createAcademy_generatesSlugAutomatically() throws Exception {
        Map<String, Object> body = Map.of(
                "name", "Academia Integração",
                "deviceLimitPerUser", 3,
                "instructorName", "Professor",
                "instructorEmail", "professor-integration@test.com",
                "instructorPassword", "senha123"
        );

        mockMvc.perform(post("/api/admin/academies")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(body)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slug").value("academia-integracao"))
                .andExpect(jsonPath("$.name").value("Academia Integração"));
    }

    @Test
    void createAcademy_requiresAuthentication() throws Exception {
        mockMvc.perform(post("/api/admin/academies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void createAcademy_validatesPayload() throws Exception {
        mockMvc.perform(post("/api/admin/academies")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }
}
