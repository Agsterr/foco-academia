package br.com.focodev.academia.service;

import br.com.focodev.academia.domain.Academy;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.*;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final DeviceService deviceService;
    private final TenantService tenantService;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        throw new ApiException("Cadastro público desativado. Peça ao instrutor ou administrador para criar sua conta.");
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

        if (user.getRole() == UserRole.ADMIN) {
            if (request.academySlug() != null && !request.academySlug().isBlank()) {
                throw new ApiException("Administrador da plataforma não usa código de academia");
            }
        } else {
            Academy academy = tenantService.requireActiveAcademyBySlug(request.academySlug());
            tenantService.requireUserBelongsToAcademy(user, academy);
        }

        deviceService.registerDevice(user, request.deviceId(), request.deviceLabel());

        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        AuthUser authUser = new AuthUser(user);
        return new AuthResponse(jwtService.generateToken(authUser), UserResponse.from(user));
    }

    public UserResponse me(AuthUser authUser) {
        User user = userRepository.findById(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        tenantService.requireActiveAcademy(user);
        return UserResponse.from(user);
    }
}
