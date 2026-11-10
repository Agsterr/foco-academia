package br.com.focodev.academia.manager;

import br.com.focodev.academia.manager.InviteDtos.*;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.LoginRateLimiter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class InviteController {

    private final InviteService inviteService;
    private final LoginRateLimiter loginRateLimiter;

    @PostMapping("/manager/invites")
    public InviteResponse create(@AuthenticationPrincipal AuthUser user, @Valid @RequestBody CreateInviteRequest request) {
        return inviteService.create(user, request);
    }

    @GetMapping("/manager/invites")
    public List<InviteResponse> list(@AuthenticationPrincipal AuthUser user) {
        return inviteService.listOpen(user);
    }

    @DeleteMapping("/manager/invites/{id}")
    public ResponseEntity<Void> revoke(@AuthenticationPrincipal AuthUser user, @PathVariable UUID id) {
        inviteService.revoke(user, id);
        return ResponseEntity.noContent().build();
    }

    /** Trocou de celular: libera o aparelho para a pessoa entrar no novo. */
    @PostMapping("/manager/members/{id}/devices/release")
    public ResponseEntity<Void> releaseDevices(@AuthenticationPrincipal AuthUser user, @PathVariable UUID id) {
        inviteService.releaseDevices(user, id);
        return ResponseEntity.noContent().build();
    }

    // Públicos: quem abre o link ainda não tem conta.

    @GetMapping("/auth/invites/{code}")
    public InvitePreview preview(@PathVariable String code, HttpServletRequest httpRequest) {
        loginRateLimiter.check(httpRequest);
        return inviteService.preview(code);
    }

    @PostMapping("/auth/invites/{code}/accept")
    public AcceptInviteResponse accept(@PathVariable String code, @Valid @RequestBody AcceptInviteRequest request,
                                       HttpServletRequest httpRequest) {
        loginRateLimiter.check(httpRequest);
        return inviteService.accept(code, request);
    }
}
