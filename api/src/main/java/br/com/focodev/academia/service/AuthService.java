package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import io.jsonwebtoken.Claims;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final DeviceService deviceService;
    private final TenantService tenantService;

    @Value("${app.jwt.refresh-grace-days:30}")
    private long refreshGraceDays;

    /** Cadastro público só de aluno avulso (sem academia). Instrutor e academia são criados pelo admin. */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (request.role() != null && request.role() != UserRole.ALUNO) {
            throw new ApiException("Cadastro público disponível apenas para alunos.");
        }
        String email = request.email().trim().toLowerCase();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ApiException("Já existe uma conta com este e-mail. Entre com sua senha.");
        }

        User user = new User();
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setName(request.name().trim());
        user.setPhone(request.phone());
        user.setRole(UserRole.ALUNO);
        user.setLastLoginAt(Instant.now());
        user = userRepository.save(user);

        if (request.deviceId() != null && !request.deviceId().isBlank()) {
            deviceService.registerDevice(
                    user,
                    request.deviceId(),
                    request.deviceLabel(),
                    request.appClient(),
                    request.appVersion()
            );
        }

        return new AuthResponse(jwtService.generateToken(new AuthUser(user)), UserResponse.from(user));
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.email().trim().toLowerCase(), request.password())
        );

        User user = userRepository.findByEmailWithAcademy(request.email().trim().toLowerCase())
                .orElseThrow(() -> new ApiException("Credenciais inválidas"));

        if (!user.isActive()) {
            throw new ApiException("Conta desativada");
        }

        boolean independentStudent = user.getRole() == UserRole.ALUNO && user.getAcademy() == null;
        if (independentStudent) {
            if (request.academySlug() != null && !request.academySlug().isBlank()) {
                throw new ApiException("Sua conta não é vinculada a uma academia. Deixe o código da academia em branco.");
            }
        } else if (user.getRole() == UserRole.ADMIN) {
            if (request.academySlug() != null && !request.academySlug().isBlank()) {
                throw new ApiException("Administrador da plataforma não usa código de academia");
            }
        } else {
            if (request.academySlug() == null || request.academySlug().isBlank()) {
                if (user.getRole() == UserRole.INSTRUTOR) {
                    throw new ApiException(
                            "Este e-mail é de instrutor. Acesse instrutor-academia.focodev.com.br e informe o código da academia."
                    );
                }
                if (user.getRole() == UserRole.ALUNO) {
                    throw new ApiException(
                            "Este e-mail é de aluno. Acesse academia.focodev.com.br e informe o código da academia."
                    );
                }
                throw new ApiException("Código da academia é obrigatório");
            }
            Academy academy = tenantService.requireActiveAcademyBySlug(request.academySlug());
            tenantService.requireUserBelongsToAcademy(user, academy);
        }

        deviceService.registerDevice(
                user,
                request.deviceId(),
                request.deviceLabel(),
                request.appClient(),
                request.appVersion()
        );

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        AuthUser authUser = new AuthUser(user);
        return new AuthResponse(jwtService.generateToken(authUser), UserResponse.from(user));
    }

    /**
     * Renova o JWT usando o token atual (válido ou expirado dentro da janela de graça).
     * Usado pelo app mobile ao abrir/voltar para manter a sessão sem novo login.
     */
    @Transactional
    public TokenRefreshResponse refreshSession(String rawToken) {
        Claims claims = jwtService.parseClaimsLenient(rawToken)
                .orElseThrow(() -> new ApiException("Token inválido", HttpStatus.UNAUTHORIZED));
        if (!jwtService.isWithinRefreshGrace(claims, refreshGraceDays)) {
            throw new ApiException("Sessão expirada. Faça login novamente.", HttpStatus.UNAUTHORIZED);
        }

        UUID userId = UUID.fromString(claims.getSubject());
        User user = userRepository.findByIdWithAcademy(userId)
                .orElseThrow(() -> new ApiException("Usuário não encontrado", HttpStatus.UNAUTHORIZED));
        if (!user.isActive()) {
            throw new ApiException("Conta desativada", HttpStatus.UNAUTHORIZED);
        }
        tenantService.requireActiveAcademy(user);

        AuthUser authUser = new AuthUser(user);
        boolean missingAcademy = authUser.getAcademyId() == null && authUser.getRole() == UserRole.INSTRUTOR;
        if ((authUser.getRole() == UserRole.INSTRUTOR || authUser.getRole() == UserRole.ALUNO)
                && (missingAcademy || !authUser.isAcademyActive())) {
            throw new ApiException("Academia desativada ou não vinculada", HttpStatus.FORBIDDEN);
        }
        if ((authUser.getRole() == UserRole.INSTRUTOR || authUser.getRole() == UserRole.ALUNO)
                && authUser.isAcademyAppBlocked()) {
            throw new ApiException("Aplicativo bloqueado para esta academia", HttpStatus.FORBIDDEN);
        }

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        return new TokenRefreshResponse(jwtService.generateToken(authUser));
    }

    public UserResponse me(AuthUser authUser) {
        User user = userRepository.findById(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        tenantService.requireActiveAcademy(user);
        return UserResponse.from(user);
    }

    @Transactional
    public void heartbeat(AuthUser authUser, HeartbeatRequest request) {
        User user = userRepository.findById(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        if (!user.isActive()) {
            throw new ApiException("Conta desativada");
        }
        tenantService.requireActiveAcademy(user);

        String deviceId = request != null ? request.deviceId() : null;
        String appVersion = request != null ? request.appVersion() : null;
        AppClientType appClient = request != null ? request.appClient() : null;

        deviceService.heartbeat(user, deviceId, appVersion, appClient);
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);
    }
}
