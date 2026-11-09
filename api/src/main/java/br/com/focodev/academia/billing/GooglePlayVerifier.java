package br.com.focodev.academia.billing;

import java.time.Instant;
import java.util.Optional;

/** Consulta no Google o estado real de uma compra de assinatura (nunca confiar só no app). */
public interface GooglePlayVerifier {

    record VerifiedSubscription(String productId, Instant expiresAt, boolean autoRenewing, boolean active) {}

    /** Vazio quando a verificação não está configurada no servidor. */
    boolean isConfigured();

    Optional<VerifiedSubscription> verify(String productId, String purchaseToken);
}
