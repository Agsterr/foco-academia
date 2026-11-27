package br.com.focodev.academia.billing;

import br.com.focodev.academia.billing.BillingDtos.AccessReason;
import br.com.focodev.academia.billing.BillingDtos.SubscriptionStatus;
import br.com.focodev.academia.domain.Subscription;
import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import br.com.focodev.academia.exception.ApiException;
import br.com.focodev.academia.repository.SubscriptionRepository;
import br.com.focodev.academia.repository.UserRepository;
import br.com.focodev.academia.security.AuthUser;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Assinatura do aluno. Todo aluno paga pela Play Store; o vinculado a uma academia ou
 * personal paga menos. Só os e-mails liberados usam de graça. O bloqueio só vale com app.billing.enforce=true, para nada travar antes de os
 * produtos existirem no Google Play Console.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class BillingService {

    private final BillingProperties properties;
    private final SubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;
    private final GooglePlayVerifier verifier;

    /** Teste grátis ao criar a conta. */
    @Transactional
    public void startTrial(User user) {
        if (subscriptionRepository.findByUserId(user.getId()).isPresent()) {
            return;
        }
        Subscription trial = new Subscription();
        trial.setUser(user);
        trial.setSource(Subscription.Source.TRIAL);
        trial.setExpiresAt(Instant.now().plus(Duration.ofDays(properties.trialDaysOrDefault())));
        subscriptionRepository.save(trial);
    }

    @Transactional
    public SubscriptionStatus status(AuthUser authUser) {
        User user = requireStudent(authUser);
        if (properties.isFreeEmail(user.getEmail())) {
            return status(user, true, AccessReason.COURTESY, null, false);
        }
        // Aluno vinculado que nunca teve teste: começa a contar quando o bloqueio já está ligado.
        if (properties.enforce() && user.getAcademy() != null) {
            startTrial(user);
        }
        Subscription sub = subscriptionRepository.findByUserId(user.getId()).orElse(null);
        if (sub == null) {
            return status(user, false, AccessReason.NONE, null, false);
        }
        refreshIfExpired(sub);
        Instant now = Instant.now();
        if (!sub.isActive(now)) {
            return status(user, false, AccessReason.NONE, sub.getExpiresAt(), false);
        }
        AccessReason reason = sub.getSource() == Subscription.Source.TRIAL ? AccessReason.TRIAL : AccessReason.SUBSCRIPTION;
        return status(user, true, reason, sub.getExpiresAt(), Boolean.TRUE.equals(sub.getAutoRenewing()));
    }

    /** Bloqueia o recurso premium quando o bloqueio está ligado e o aluno não tem acesso. */
    @Transactional
    public void requirePremium(AuthUser authUser) {
        if (!properties.enforce()) {
            return;
        }
        if (!status(authUser).premium()) {
            throw new ApiException(
                    "Recurso do Foco Premium. Assine para usar treinos prontos e montar seus treinos.",
                    HttpStatus.PAYMENT_REQUIRED
            );
        }
    }

    /** Ficha passada pelo instrutor: aluno vinculado sem assinatura não abre. Aluno avulso não é afetado. */
    @Transactional
    public void requirePlanAccess(AuthUser authUser) {
        if (!properties.enforce() || authUser.getRole() != UserRole.ALUNO) {
            return;
        }
        if (requireStudent(authUser).getAcademy() != null && !status(authUser).premium()) {
            throw new ApiException(
                    "Assine o Foco Premium para abrir a ficha do seu instrutor.",
                    HttpStatus.PAYMENT_REQUIRED
            );
        }
    }

    /** Recebe a compra feita no app, confirma no Google e libera o acesso. */
    @Transactional
    public SubscriptionStatus applyGooglePlayPurchase(AuthUser authUser, BillingDtos.GooglePlayPurchaseRequest request) {
        User user = requireStudent(authUser);
        if (!productIdsFor(user).contains(request.productId())) {
            throw new ApiException("Plano desconhecido.");
        }
        if (!verifier.isConfigured()) {
            throw new ApiException("Assinatura ainda não configurada no servidor.", HttpStatus.SERVICE_UNAVAILABLE);
        }
        subscriptionRepository.findByPurchaseToken(request.purchaseToken())
                .filter(other -> !other.getUser().getId().equals(user.getId()))
                .ifPresent(other -> {
                    throw new ApiException("Esta compra já está vinculada a outra conta.", HttpStatus.CONFLICT);
                });

        GooglePlayVerifier.VerifiedSubscription verified = verifier
                .verify(request.productId(), request.purchaseToken())
                .orElseThrow(() -> new ApiException("Assinatura ainda não configurada no servidor.",
                        HttpStatus.SERVICE_UNAVAILABLE));
        if (!verified.active()) {
            throw new ApiException("Esta assinatura não está ativa no Google Play.");
        }

        Subscription sub = subscriptionRepository.findByUserId(user.getId()).orElseGet(() -> {
            Subscription created = new Subscription();
            created.setUser(user);
            return created;
        });
        sub.setSource(Subscription.Source.GOOGLE_PLAY);
        sub.setProductId(verified.productId());
        sub.setPurchaseToken(request.purchaseToken());
        sub.setExpiresAt(verified.expiresAt());
        sub.setAutoRenewing(verified.autoRenewing());
        sub.setUpdatedAt(Instant.now());
        subscriptionRepository.save(sub);
        return status(authUser);
    }

    /** Admin libera acesso manualmente (cortesia, parceria, suporte). */
    @Transactional
    public void grant(UUID userId, int days) {
        User user = userRepository.findById(userId).orElseThrow(() -> new ApiException("Usuário não encontrado"));
        if (user.getRole() != UserRole.ALUNO) {
            throw new ApiException("Só alunos têm assinatura.");
        }
        Subscription sub = subscriptionRepository.findByUserId(userId).orElseGet(() -> {
            Subscription created = new Subscription();
            created.setUser(user);
            return created;
        });
        Instant base = sub.isActive(Instant.now()) ? sub.getExpiresAt() : Instant.now();
        if (sub.getSource() != Subscription.Source.GOOGLE_PLAY) {
            sub.setSource(Subscription.Source.ADMIN);
        }
        sub.setExpiresAt(base.plus(Duration.ofDays(days)));
        sub.setUpdatedAt(Instant.now());
        subscriptionRepository.save(sub);
    }

    /** Renovação automática: o app não avisa, então consulta o Google quando o prazo salvo passou. */
    private void refreshIfExpired(Subscription sub) {
        if (sub.isActive(Instant.now())
                || sub.getSource() != Subscription.Source.GOOGLE_PLAY
                || sub.getPurchaseToken() == null
                || !verifier.isConfigured()) {
            return;
        }
        try {
            verifier.verify(sub.getProductId(), sub.getPurchaseToken()).ifPresent(v -> {
                sub.setExpiresAt(v.expiresAt());
                sub.setAutoRenewing(v.autoRenewing());
                sub.setUpdatedAt(Instant.now());
                subscriptionRepository.save(sub);
            });
        } catch (Exception e) {
            log.info("Não foi possível revalidar assinatura vencida: {}", e.getMessage());
        }
    }

    private List<String> productIdsFor(User user) {
        return user.getAcademy() != null ? properties.linkedProductIdsOrDefault() : properties.productIdsOrDefault();
    }

    private SubscriptionStatus status(User user, boolean premium, AccessReason reason, Instant expiresAt, boolean autoRenewing) {
        return new SubscriptionStatus(
                premium || !properties.enforce(),
                reason,
                expiresAt,
                autoRenewing,
                properties.enforce(),
                verifier.isConfigured(),
                productIdsFor(user),
                user.getAcademy() != null
        );
    }

    private User requireStudent(AuthUser authUser) {
        User user = userRepository.findById(authUser.getId())
                .orElseThrow(() -> new ApiException("Aluno não encontrado"));
        if (user.getRole() != UserRole.ALUNO) {
            throw new ApiException("Acesso negado");
        }
        return user;
    }
}
