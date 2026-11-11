package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.BodyMeasurement;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.repository.BodyMeasurementRepository;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AccountDeletionIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired UserRepository userRepository;
    @Autowired BodyMeasurementRepository bodyMeasurementRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    private User student;
    private String studentToken;

    @BeforeEach
    void setUp() {
        student = new User();
        student.setEmail("aluno-exclusao@test.com");
        student.setName("Aluno Exclusão");
        student.setPhone("11999990000");
        student.setPasswordHash(passwordEncoder.encode("senha123"));
        student.setRole(UserRole.ALUNO);
        userRepository.save(student);

        BodyMeasurement m = new BodyMeasurement();
        m.setStudent(student);
        m.setWeightKg(80.0);
        bodyMeasurementRepository.save(m);

        studentToken = jwtService.generateToken(new AuthUser(student));
    }

    private org.springframework.test.web.servlet.ResultActions deleteWith(String token, String password) throws Exception {
        return mockMvc.perform(delete("/api/student/account")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("password", password))));
    }

    @Test
    void wrongPassword_isRejectedAndKeepsData() throws Exception {
        deleteWith(studentToken, "errada").andExpect(status().isForbidden());

        assertEquals(1, bodyMeasurementRepository.count());
        assertEquals("aluno-exclusao@test.com", userRepository.findById(student.getId()).orElseThrow().getEmail());
    }

    @Test
    void correctPassword_deletesPersonalDataAndAnonymizes() throws Exception {
        deleteWith(studentToken, "senha123").andExpect(status().isNoContent());

        assertEquals(0, bodyMeasurementRepository.count());
        User after = userRepository.findById(student.getId()).orElseThrow();
        assertFalse(after.isActive());
        assertEquals("Conta excluída", after.getName());
        assertEquals(null, after.getPhone());
        assertNotEquals("aluno-exclusao@test.com", after.getEmail());
        assertFalse(passwordEncoder.matches("senha123", after.getPasswordHash()));
    }

    @Test
    void instructorCannotUseStudentEndpoint() throws Exception {
        User instructor = new User();
        instructor.setEmail("instrutor-exclusao@test.com");
        instructor.setName("Instrutor");
        instructor.setPasswordHash(passwordEncoder.encode("senha123"));
        instructor.setRole(UserRole.INSTRUTOR);
        userRepository.save(instructor);
        String token = jwtService.generateToken(new AuthUser(instructor));

        deleteWith(token, "senha123").andExpect(status().isForbidden());
    }

    @Test
    void requiresAuthentication() throws Exception {
        mockMvc.perform(delete("/api/student/account")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"password\":\"x\"}"))
                .andExpect(status().isUnauthorized());
    }
}
