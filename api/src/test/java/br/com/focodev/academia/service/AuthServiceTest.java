package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.AuthResponse;
import br.com.focodev.academia.dto.HeartbeatRequest;
import br.com.focodev.academia.dto.LoginRequest;
import br.com.focodev.academia.dto.RegisterRequest;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Date;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtService jwtService;
    @Mock AuthenticationManager authenticationManager;
    @Mock DeviceService deviceService;
    @Mock TenantService tenantService;

    @InjectMocks AuthService authService;

    private User admin;
    private User instructor;
    private User student;
    private Academy academy;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(authService, "refreshGraceDays", 30L);
        academy = new Academy();
        academy.setId(UUID.randomUUID());
        academy.setSlug("academia-demo");
        academy.setActive(true);

        admin = new User();
        admin.setId(UUID.randomUUID());
        admin.setEmail("admin@test.com");
        admin.setRole(UserRole.ADMIN);
        admin.setActive(true);

        instructor = new User();
        instructor.setId(UUID.randomUUID());
        instructor.setEmail("instrutor@test.com");
        instructor.setRole(UserRole.INSTRUTOR);
        instructor.setAcademy(academy);
        instructor.setActive(true);

        student = new User();
        student.setId(UUID.randomUUID());
        student.setEmail("aluno@test.com");
        student.setRole(UserRole.ALUNO);
        student.setAcademy(academy);
        student.setActive(true);
    }

    @Test
    void register_isDisabled() {
        assertThrows(ApiException.class, () -> authService.register(
                new RegisterRequest("a@test.com", "senha123", "Nome", null, UserRole.ALUNO)));
    }

    @Test
    void login_adminSuccess() {
        when(userRepository.findByEmailWithAcademy("admin@test.com")).thenReturn(Optional.of(admin));
        when(jwtService.generateToken(any(AuthUser.class))).thenReturn("token");

        AuthResponse response = authService.login(new LoginRequest(
                "admin@test.com", "senha123", null, "dev", "Chrome", null, null));

        assertEquals("token", response.token());
        verify(deviceService).registerDevice(admin, "dev", "Chrome", null, null);
    }

    @Test
    void login_adminRejectsAcademySlug() {
        when(userRepository.findByEmailWithAcademy("admin@test.com")).thenReturn(Optional.of(admin));

        assertThrows(ApiException.class, () -> authService.login(new LoginRequest(
                "admin@test.com", "senha123", "academia-demo", "dev", null, null, null)));
    }

    @Test
    void login_instructorRequiresAcademy() {
        when(userRepository.findByEmailWithAcademy("instrutor@test.com")).thenReturn(Optional.of(instructor));
        when(tenantService.requireActiveAcademyBySlug("academia-demo")).thenReturn(academy);
        when(jwtService.generateToken(any(AuthUser.class))).thenReturn("token");

        AuthResponse response = authService.login(new LoginRequest(
                "instrutor@test.com", "senha123", "academia-demo", "dev", null, null, null));

        assertEquals("token", response.token());
        verify(tenantService).requireUserBelongsToAcademy(instructor, academy);
    }

    @Test
    void login_mobileStudentPersistsClientAndVersion() {
        when(userRepository.findByEmailWithAcademy("aluno@test.com")).thenReturn(Optional.of(student));
        when(tenantService.requireActiveAcademyBySlug("academia-demo")).thenReturn(academy);
        when(jwtService.generateToken(any(AuthUser.class))).thenReturn("token");

        AuthResponse response = authService.login(new LoginRequest(
                "aluno@test.com",
                "senha123",
                "academia-demo",
                "phone-1",
                "Flutter Android",
                AppClientType.MOBILE,
                "1.0.1+16"
        ));

        assertEquals("token", response.token());
        verify(deviceService).registerDevice(
                student, "phone-1", "Flutter Android", AppClientType.MOBILE, "1.0.1+16");
    }

    @Test
    void login_rejectsInactiveUser() {
        instructor.setActive(false);
        when(userRepository.findByEmailWithAcademy("instrutor@test.com")).thenReturn(Optional.of(instructor));

        assertThrows(ApiException.class, () -> authService.login(new LoginRequest(
                "instrutor@test.com", "senha123", "academia-demo", "dev", null, null, null)));
    }

    @Test
    void heartbeat_updatesDeviceAndLastLogin() {
        when(userRepository.findById(student.getId())).thenReturn(Optional.of(student));

        authService.heartbeat(
                new AuthUser(student),
                new HeartbeatRequest("phone-1", "1.0.1+16", AppClientType.MOBILE)
        );

        verify(tenantService).requireActiveAcademy(student);
        verify(deviceService).heartbeat(student, "phone-1", "1.0.1+16", AppClientType.MOBILE);
        verify(userRepository).save(student);
        assertNotNull(student.getLastLoginAt());
    }

    @Test
    void heartbeat_rejectsInactiveUser() {
        student.setActive(false);
        when(userRepository.findById(student.getId())).thenReturn(Optional.of(student));

        assertThrows(ApiException.class, () -> authService.heartbeat(
                new AuthUser(student),
                new HeartbeatRequest("phone-1", "1.0.0+1", AppClientType.MOBILE)
        ));
        verify(deviceService, never()).heartbeat(any(), any(), any(), any());
    }

    @Test
    void me_returnsUser() {
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));
        AuthUser authUser = new AuthUser(admin);

        assertEquals("admin@test.com", authService.me(authUser).email());
    }

    @Test
    void me_checksActiveAcademyForInstructor() {
        when(userRepository.findById(instructor.getId())).thenReturn(Optional.of(instructor));
        AuthUser authUser = new AuthUser(instructor);

        assertEquals("instrutor@test.com", authService.me(authUser).email());
        verify(tenantService).requireActiveAcademy(instructor);
    }

    @Test
    void me_notFound() {
        when(userRepository.findById(any())).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> authService.me(new AuthUser(admin)));
    }

    @Test
    void refreshSession_issuesNewTokenWithinGrace() {
        Claims claims = mock(Claims.class);
        when(claims.getSubject()).thenReturn(student.getId().toString());
        when(jwtService.parseClaimsLenient("old-token")).thenReturn(Optional.of(claims));
        when(jwtService.isWithinRefreshGrace(claims, 30L)).thenReturn(true);
        when(userRepository.findByIdWithAcademy(student.getId())).thenReturn(Optional.of(student));
        when(jwtService.generateToken(any(AuthUser.class))).thenReturn("new-token");

        var response = authService.refreshSession("old-token");

        assertEquals("new-token", response.token());
        verify(tenantService).requireActiveAcademy(student);
    }
}
