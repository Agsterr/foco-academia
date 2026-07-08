package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.AuthResponse;
import br.com.focodev.academia.dto.LoginRequest;
import br.com.focodev.academia.dto.RegisterRequest;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

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
    private Academy academy;

    @BeforeEach
    void setUp() {
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
                "admin@test.com", "senha123", null, "dev", "Chrome"));

        assertEquals("token", response.token());
        verify(deviceService).registerDevice(admin, "dev", "Chrome");
    }

    @Test
    void login_adminRejectsAcademySlug() {
        when(userRepository.findByEmailWithAcademy("admin@test.com")).thenReturn(Optional.of(admin));

        assertThrows(ApiException.class, () -> authService.login(new LoginRequest(
                "admin@test.com", "senha123", "academia-demo", "dev", null)));
    }

    @Test
    void login_instructorRequiresAcademy() {
        when(userRepository.findByEmailWithAcademy("instrutor@test.com")).thenReturn(Optional.of(instructor));
        when(tenantService.requireActiveAcademyBySlug("academia-demo")).thenReturn(academy);
        when(jwtService.generateToken(any(AuthUser.class))).thenReturn("token");

        AuthResponse response = authService.login(new LoginRequest(
                "instrutor@test.com", "senha123", "academia-demo", "dev", null));

        assertEquals("token", response.token());
        verify(tenantService).requireUserBelongsToAcademy(instructor, academy);
    }

    @Test
    void login_rejectsInactiveUser() {
        instructor.setActive(false);
        when(userRepository.findByEmailWithAcademy("instrutor@test.com")).thenReturn(Optional.of(instructor));

        assertThrows(ApiException.class, () -> authService.login(new LoginRequest(
                "instrutor@test.com", "senha123", "academia-demo", "dev", null)));
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
}
