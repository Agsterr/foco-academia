package br.com.focodev.academia.manager;

import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.dto.UserResponse;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class InviteDtos {

    private InviteDtos() {}

    /** role ALUNO (instrutor convida aluno) ou INSTRUTOR (academia convida instrutor). */
    public record CreateInviteRequest(
            @NotNull UserRole role,
            @Size(max = 120) String name,
            /** Só para aluno, quando quem convida é o gestor: instrutor responsável. */
            UUID instructorId
    ) {}

    public record InviteResponse(
            UUID id,
            String code,
            String url,
            UserRole role,
            String name,
            String instructorName,
            Instant expiresAt,
            /** Texto pronto para mandar no WhatsApp. */
            String shareText
    ) {}

    /** O que a tela do convite mostra antes de a pessoa aceitar. */
    public record InvitePreview(
            String code,
            UserRole role,
            String academyName,
            String instructorName,
            String invitedBy,
            String name,
            boolean personal,
            Instant expiresAt
    ) {}

    /**
     * Aceite do convite. E-mail novo cria a conta; e-mail de aluno avulso que já usa o app
     * (com a senha certa) vincula a conta existente à academia.
     */
    public record AcceptInviteRequest(
            @Size(max = 120) String name,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, max = 100) String password,
            @NotBlank String deviceId,
            String deviceLabel,
            AppClientType appClient,
            String appVersion
    ) {}

    public record AcceptInviteResponse(String token, UserResponse user, String academySlug, boolean linkedExistingAccount) {}
}
