package br.com.focodev.academia.manager;

import br.com.focodev.academia.domain.*;
import br.com.focodev.academia.dto.UserResponse;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.manager.InviteDtos.*;
import br.com.focodev.academia.repository.DeviceSessionRepository;
import br.com.focodev.academia.repository.InviteRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import br.com.focodev.academia.security.JwtService;
import br.com.focodev.academia.service.DeviceService;
import br.com.focodev.academia.service.TenantService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Convites por link: a academia convida instrutores e o instrutor (ou gestor) convida alunos.
 *
 * <p>Segurança contra repassar o link: o código vale uma vez só, vence em 7 dias, e a conta criada
 * fica presa a um aparelho ({@link User#isSingleDevice()}).
 */
@Service
@RequiredArgsConstructor
public class InviteService {

    static final Duration VALIDITY = Duration.ofDays(7);
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int CODE_LENGTH = 10;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final InviteRepository inviteRepository;
    private final UserRepository userRepository;
    private final DeviceSessionRepository deviceSessionRepository;
    private final TenantService tenantService;
    private final DeviceService deviceService;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    @Value("${app.releases.public-base-url:https://academia.focodev.com.br}")
    private String publicBaseUrl;

    // ---------------------------------------------------------------- quem convida

    @Transactional
    public InviteResponse create(AuthUser authUser, CreateInviteRequest request) {
        User inviter = requireStaff(authUser);
        Academy academy = inviter.getAcademy();
        boolean manager = ManagerService.isManager(inviter);

        Invite invite = new Invite();
        invite.setAcademy(academy);
        invite.setCreatedBy(inviter);
        invite.setRole(request.role());
        invite.setName(blankToNull(request.name()));
        invite.setExpiresAt(Instant.now().plus(VALIDITY));

        if (request.role() == UserRole.INSTRUTOR) {
            if (!manager || inviter.getRole() != UserRole.GESTOR) {
                throw new ApiException("Só a academia convida instrutores.", HttpStatus.FORBIDDEN);
            }
        } else if (request.role() == UserRole.ALUNO) {
            if (manager && request.instructorId() != null) {
                invite.setInstructor(userRepository.findById(request.instructorId())
                        .filter(u -> u.getRole() == UserRole.INSTRUTOR && u.isActive() && sameAcademy(u, academy))
                        .orElseThrow(() -> new ApiException("Instrutor não encontrado nesta academia")));
            } else if (inviter.getRole() == UserRole.INSTRUTOR) {
                // Instrutor convida para si mesmo (inclusive o personal autônomo).
                invite.setInstructor(inviter);
            }
        } else {
            throw new ApiException("Convite só para aluno ou instrutor.");
        }

        invite.setCode(newCode());
        return toResponse(inviteRepository.save(invite), academy);
    }

    /** Convites ainda abertos: o gestor vê todos da academia; o instrutor, os que ele mandou. */
    @Transactional(readOnly = true)
    public List<InviteResponse> listOpen(AuthUser authUser) {
        User user = requireStaff(authUser);
        boolean manager = ManagerService.isManager(user);
        return inviteRepository.findOpenByAcademy(user.getAcademy().getId(), Instant.now()).stream()
                .filter(i -> manager || i.getCreatedBy().getId().equals(user.getId()))
                .map(i -> toResponse(i, user.getAcademy()))
                .toList();
    }

    @Transactional
    public void revoke(AuthUser authUser, UUID inviteId) {
        User user = requireStaff(authUser);
        Invite invite = inviteRepository.findById(inviteId)
                .filter(i -> sameAcademy(i.getAcademy(), user.getAcademy()))
                .filter(i -> ManagerService.isManager(user) || i.getCreatedBy().getId().equals(user.getId()))
                .orElseThrow(() -> new ApiException("Convite não encontrado"));
        invite.setRevoked(true);
        inviteRepository.save(invite);
    }

    /**
     * Libera o aparelho de um aluno ou instrutor (trocou de celular): o próximo aparelho em que ele
     * entrar fica sendo o dele. O gestor libera qualquer pessoa da academia; o instrutor, os próprios alunos.
     */
    @Transactional
    public void releaseDevices(AuthUser authUser, UUID memberId) {
        User user = requireStaff(authUser);
        User member = userRepository.findById(memberId)
                .filter(u -> sameAcademy(u, user.getAcademy()))
                .orElseThrow(() -> new ApiException("Pessoa não encontrada nesta academia"));
        boolean allowed = ManagerService.isManager(user)
                || (member.getRole() == UserRole.ALUNO && member.getInstructor() != null
                    && member.getInstructor().getId().equals(user.getId()));
        if (!allowed) {
            throw new ApiException("Você só libera o aparelho dos seus alunos.", HttpStatus.FORBIDDEN);
        }
        deviceSessionRepository.deleteAll(deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(member.getId()));
    }

    // ---------------------------------------------------------------- quem é convidado (público)

    @Transactional(readOnly = true)
    public InvitePreview preview(String rawCode) {
        Invite invite = openInvite(inviteRepository.findByCode(normalize(rawCode)).orElse(null));
        return new InvitePreview(
                invite.getCode(),
                invite.getRole(),
                invite.getAcademy().getName(),
                invite.getInstructor() != null ? invite.getInstructor().getName() : null,
                invite.getCreatedBy().getName(),
                invite.getName(),
                invite.getAcademy().isPersonal(),
                invite.getExpiresAt()
        );
    }

    @Transactional
    public AcceptInviteResponse accept(String rawCode, AcceptInviteRequest request) {
        Invite invite = openInvite(inviteRepository.lockByCode(normalize(rawCode)).orElse(null));
        Academy academy = invite.getAcademy();
        if (!academy.isActive()) {
            throw new ApiException("Academia desativada. Fale com a academia.");
        }

        String email = request.email().trim().toLowerCase(Locale.ROOT);
        User user = userRepository.findByEmailWithAcademy(email).orElse(null);
        boolean linked = user != null;
        if (user == null) {
            String name = blankToNull(request.name()) != null ? request.name().trim() : invite.getName();
            if (name == null || name.isBlank()) {
                throw new ApiException("Informe seu nome.");
            }
            user = new User();
            user.setEmail(email);
            user.setName(name);
            user.setPasswordHash(passwordEncoder.encode(request.password()));
            user.setRole(invite.getRole());
        } else {
            // Aluno avulso que já usa o app: vincula a mesma conta (histórico e treinos continuam).
            boolean independentStudent = user.getRole() == UserRole.ALUNO && user.getAcademy() == null;
            if (invite.getRole() != UserRole.ALUNO || !independentStudent) {
                throw new ApiException("Já existe uma conta com este e-mail. Use outro e-mail para aceitar o convite.");
            }
            if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
                throw new ApiException("Este e-mail já tem conta no app. Digite a senha dela para vincular à academia.");
            }
            if (!user.isActive()) {
                throw new ApiException("Conta desativada");
            }
            // A conta passa a valer só neste aparelho.
            deviceSessionRepository.deleteAll(deviceSessionRepository.findByUserIdOrderByLastSeenAtDesc(user.getId()));
        }
        user.setAcademy(academy);
        user.setInstructor(invite.getRole() == UserRole.ALUNO ? invite.getInstructor() : null);
        user.setSingleDevice(true);
        user.setLastLoginAt(Instant.now());
        user = userRepository.save(user);

        deviceService.registerDevice(user, request.deviceId(), request.deviceLabel(), request.appClient(), request.appVersion());

        invite.setUsedAt(Instant.now());
        invite.setUsedBy(user);
        inviteRepository.save(invite);

        return new AcceptInviteResponse(
                jwtService.generateToken(new AuthUser(user)), UserResponse.from(user), academy.getSlug(), linked);
    }

    // ---------------------------------------------------------------- apoio

    private User requireStaff(AuthUser authUser) {
        User user = userRepository.findByIdWithAcademy(authUser.getId())
                .orElseThrow(() -> new ApiException("Usuário não encontrado"));
        if ((user.getRole() != UserRole.GESTOR && user.getRole() != UserRole.INSTRUTOR) || user.getAcademy() == null) {
            throw new ApiException("Disponível só para a equipe da academia.", HttpStatus.FORBIDDEN);
        }
        tenantService.requireActiveAcademy(user);
        return user;
    }

    private static Invite openInvite(Invite invite) {
        if (invite == null) {
            throw new ApiException("Convite não encontrado. Confira o link ou peça um novo.", HttpStatus.NOT_FOUND);
        }
        if (invite.getUsedAt() != null) {
            throw new ApiException("Este convite já foi usado. Cada convite vale para uma pessoa só; peça um novo.",
                    HttpStatus.GONE);
        }
        if (invite.isRevoked() || !invite.getExpiresAt().isAfter(Instant.now())) {
            throw new ApiException("Este convite venceu. Peça um novo para quem te convidou.", HttpStatus.GONE);
        }
        return invite;
    }

    private InviteResponse toResponse(Invite invite, Academy academy) {
        String url = publicBaseUrl.replaceAll("/+$", "") + "/convite/" + invite.getCode();
        String who = invite.getRole() == UserRole.INSTRUTOR
                ? "para ser instrutor(a) na " + academy.getName()
                : (invite.getInstructor() != null
                    ? "para treinar com " + invite.getInstructor().getName()
                        + (academy.isPersonal() ? "" : " na " + academy.getName())
                    : "para treinar na " + academy.getName());
        String greeting = invite.getName() != null ? "Oi, " + invite.getName().split(" ")[0] + "! " : "Oi! ";
        String shareText = greeting + "Você foi convidado(a) " + who + " no app Foco Academia. "
                + "Toque no link para entrar (vale para um aparelho e vence em 7 dias): " + url
                + "\nSe preferir, abra o app e digite o código " + formatted(invite.getCode()) + ".";
        return new InviteResponse(
                invite.getId(),
                invite.getCode(),
                url,
                invite.getRole(),
                invite.getName(),
                invite.getInstructor() != null ? invite.getInstructor().getName() : null,
                invite.getExpiresAt(),
                shareText
        );
    }

    private String newCode() {
        for (int attempt = 0; attempt < 10; attempt++) {
            StringBuilder sb = new StringBuilder(CODE_LENGTH);
            for (int i = 0; i < CODE_LENGTH; i++) {
                sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
            }
            String code = sb.toString();
            if (!inviteRepository.existsByCode(code)) {
                return code;
            }
        }
        throw new IllegalStateException("Não foi possível gerar um código de convite");
    }

    /** "k7q2m-x9p3t" ou "K7Q2M X9P3T" → "K7Q2MX9P3T". */
    static String normalize(String raw) {
        return raw == null ? "" : raw.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
    }

    /** "K7Q2MX9P3T" → "K7Q2M-X9P3T" (mais fácil de ler e digitar). */
    static String formatted(String code) {
        return code.length() == CODE_LENGTH ? code.substring(0, 5) + "-" + code.substring(5) : code;
    }

    private static boolean sameAcademy(User user, Academy academy) {
        return user.getAcademy() != null && sameAcademy(user.getAcademy(), academy);
    }

    private static boolean sameAcademy(Academy a, Academy b) {
        return a != null && b != null && a.getId().equals(b.getId());
    }

    private static String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
