package br.com.focodev.academia.security;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;

/**
 * Exige contato online recente (heartbeat/login/refresh) para alunos.
 */
@Component
@RequiredArgsConstructor
public class OfflineAccessFilter extends OncePerRequestFilter {

    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    @Value("${app.auth.max-offline-hours:48}")
    private long maxOfflineHours;

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (!request.getRequestURI().startsWith("/api/student/")) {
            filterChain.doFilter(request, response);
            return;
        }

        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthUser authUser)) {
            filterChain.doFilter(request, response);
            return;
        }
        if (authUser.getRole() != UserRole.ALUNO) {
            filterChain.doFilter(request, response);
            return;
        }

        User user = userRepository.findById(authUser.getId()).orElse(null);
        if (user == null || user.getLastLoginAt() == null) {
            filterChain.doFilter(request, response);
            return;
        }

        Instant cutoff = Instant.now().minus(maxOfflineHours, ChronoUnit.HOURS);
        if (user.getLastLoginAt().isBefore(cutoff)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            objectMapper.writeValue(
                    response.getOutputStream(),
                    Map.of(
                            "message",
                            "Sessão offline expirada. Conecte-se à internet e abra o app para continuar."
                    )
            );
            return;
        }

        filterChain.doFilter(request, response);
    }
}
