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

import java.util.Map;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class SuggestionsIntegrationTest {

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
    void studentCreatesSuggestion_andInstructorResponds() throws Exception {
        mockMvc.perform(post("/api/student/suggestions")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "message", "Podemos ter mais halteres?",
                                "category", "Equipamento"
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Podemos ter mais halteres?"))
                .andExpect(jsonPath("$.category").value("Equipamento"))
                .andExpect(jsonPath("$.status").value("PENDENTE"));

        String listResponse = mockMvc.perform(get("/api/instructor/suggestions")
                        .header("Authorization", "Bearer " + fixture.instructorToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].student.name").value(fixture.student().getName()))
                .andExpect(jsonPath("$[0].message").value("Podemos ter mais halteres?"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        String suggestionId = objectMapper.readTree(listResponse).get(0).get("id").asText();

        mockMvc.perform(post("/api/instructor/suggestions/" + suggestionId + "/respond")
                        .header("Authorization", "Bearer " + fixture.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "response", "Vou solicitar mais halteres ao administrador."
                        ))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESPONDIDA"))
                .andExpect(jsonPath("$.response").value("Vou solicitar mais halteres ao administrador."));

        mockMvc.perform(get("/api/student/suggestions")
                        .header("Authorization", "Bearer " + fixture.studentToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].response").value("Vou solicitar mais halteres ao administrador."))
                .andExpect(jsonPath("$[0].status").value("RESPONDIDA"));
    }

    @Test
    void studentSuggestion_requiresMessage() throws Exception {
        mockMvc.perform(post("/api/student/suggestions")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void instructorCannotRespondToAnotherInstructorsSuggestion() throws Exception {
        String createResponse = mockMvc.perform(post("/api/student/suggestions")
                        .header("Authorization", "Bearer " + fixture.studentToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "message", "Sugestão privada"
                        ))))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String suggestionId = objectMapper.readTree(createResponse).get("id").asText();

        AcademyFixture otherInstructor = AcademyFixture.create(
                academyRepository, userRepository, passwordEncoder, jwtService);

        mockMvc.perform(post("/api/instructor/suggestions/" + suggestionId + "/respond")
                        .header("Authorization", "Bearer " + otherInstructor.instructorToken())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(Map.of(
                                "response", "Não deveria conseguir"
                        ))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Acesso negado"));
    }
}
