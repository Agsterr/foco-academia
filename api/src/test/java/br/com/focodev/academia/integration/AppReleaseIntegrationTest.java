package br.com.focodev.academia.integration;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.repository.AcademyRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.mock.web.MockPart;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@Transactional
class AppReleaseIntegrationTest {

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;
    @Autowired AcademyRepository academyRepository;
    @Autowired PasswordEncoder passwordEncoder;
    @Autowired JwtService jwtService;

    @Value("${app.releases.deploy-token}")
    String deployToken;

    private String adminToken;

    @BeforeEach
    void setUp() {
        User admin = new User();
        admin.setEmail("admin-release@test.com");
        admin.setName("Admin Release");
        admin.setPasswordHash(passwordEncoder.encode("admin123"));
        admin.setRole(UserRole.ADMIN);
        userRepository.save(admin);
        adminToken = jwtService.generateToken(new AuthUser(admin));
    }

    @Test
    void deployKeepsOnlyMaxRetainedReleasesInDatabase() throws Exception {
        byte[] apk = new byte[] {0x50, 0x4B, 0x03, 0x04, 0x09};
        for (int code = 30; code <= 32; code++) {
            mockMvc.perform(multipart("/api/app/releases/deploy")
                            .file(new MockMultipartFile("file", "app.apk", "application/octet-stream", apk))
                            .part(new MockPart("versionName", ("1.0." + code).getBytes()))
                            .part(new MockPart("versionCode", String.valueOf(code).getBytes()))
                            .header("X-Deploy-Token", deployToken))
                    .andExpect(status().isOk());
        }

        mockMvc.perform(get("/api/admin/releases")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].versionCode").value(32))
                .andExpect(jsonPath("$[1].versionCode").value(31));

        mockMvc.perform(get("/api/app/version"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.versionCode").value(32));
    }

    @Test
    void deployAndCheckVersion() throws Exception {
        byte[] apk = new byte[] {0x50, 0x4B, 0x03, 0x04, 0x00};
        mockMvc.perform(multipart("/api/app/releases/deploy")
                        .file(new MockMultipartFile("file", "app.apk", "application/vnd.android.package-archive", apk))
                        .part(new MockPart("versionName", "1.0.0".getBytes()))
                        .part(new MockPart("versionCode", "10".getBytes()))
                        .header("X-Deploy-Token", deployToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.versionCode").value(10));

        mockMvc.perform(get("/api/app/version"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.versionCode").value(10))
                .andExpect(jsonPath("$.downloadUrl").exists());
    }

    @Test
    void adminListsReleasesAndToggleForce() throws Exception {
        byte[] apk = new byte[] {0x50, 0x4B, 0x03, 0x04, 0x01};
        String body = mockMvc.perform(multipart("/api/app/releases/deploy")
                        .file(new MockMultipartFile("file", "app.apk", "application/octet-stream", apk))
                        .part(new MockPart("versionName", "1.0.1".getBytes()))
                        .part(new MockPart("versionCode", "11".getBytes()))
                        .header("X-Deploy-Token", deployToken))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        String id = body.replaceAll("(?s).*\"id\"\\s*:\\s*\"([^\"]+)\".*", "$1");

        mockMvc.perform(get("/api/admin/releases")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].versionCode").value(11));

        mockMvc.perform(patch("/api/admin/releases/" + id + "/force-update")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType("application/json")
                        .content("{\"forceUpdate\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.forceUpdate").value(true));
    }

    @Test
    void deployRejectsInvalidToken() throws Exception {
        byte[] apk = new byte[] {0x50, 0x4B, 0x03, 0x04};
        mockMvc.perform(multipart("/api/app/releases/deploy")
                        .file(new MockMultipartFile("file", "app.apk", "application/octet-stream", apk))
                        .part(new MockPart("versionName", "1.0.0".getBytes()))
                        .part(new MockPart("versionCode", "99".getBytes()))
                        .header("X-Deploy-Token", "wrong-token"))
                .andExpect(status().isForbidden());
    }

    @Test
    void connectedDevicesReflectMobileLoginAndNeedsUpdate() throws Exception {
        Academy academy = new Academy();
        academy.setName("Academia Mobile");
        academy.setSlug("academia-mobile-release");
        academy.setDeviceLimitPerUser(3);
        academyRepository.save(academy);

        User student = new User();
        student.setEmail("mobile-aluno@test.com");
        student.setName("Aluno Mobile");
        student.setPasswordHash(passwordEncoder.encode("senha123"));
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        userRepository.save(student);

        byte[] apk = new byte[] {0x50, 0x4B, 0x03, 0x04, 0x02};
        mockMvc.perform(multipart("/api/app/releases/deploy")
                        .file(new MockMultipartFile("file", "app.apk", "application/octet-stream", apk))
                        .part(new MockPart("versionName", "1.0.2".getBytes()))
                        .part(new MockPart("versionCode", "20".getBytes()))
                        .header("X-Deploy-Token", deployToken))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/auth/login")
                        .contentType("application/json")
                        .content("""
                                {
                                  "email":"mobile-aluno@test.com",
                                  "password":"senha123",
                                  "academySlug":"academia-mobile-release",
                                  "deviceId":"phone-abc",
                                  "deviceLabel":"Flutter Android",
                                  "appClient":"MOBILE",
                                  "appVersion":"1.0.0+10"
                                }
                                """))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/releases/connected-devices")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].deviceId").value("phone-abc"))
                .andExpect(jsonPath("$[0].appClient").value("MOBILE"))
                .andExpect(jsonPath("$[0].appVersion").value("1.0.0+10"))
                .andExpect(jsonPath("$[0].appVersionCode").value(10))
                .andExpect(jsonPath("$[0].needsUpdate").value(true));

        String studentToken = jwtService.generateToken(new AuthUser(student));
        mockMvc.perform(post("/api/auth/heartbeat")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType("application/json")
                        .content("""
                                {
                                  "deviceId":"phone-abc",
                                  "appVersion":"1.0.2+20",
                                  "appClient":"MOBILE"
                                }
                                """))
                .andExpect(status().isNoContent());

        mockMvc.perform(get("/api/admin/releases/connected-devices")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].appVersion").value("1.0.2+20"))
                .andExpect(jsonPath("$[0].appVersionCode").value(20))
                .andExpect(jsonPath("$[0].needsUpdate").value(false));
    }
}
