package br.com.focodev.academia.billing;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

public final class BillingDtos {

    private BillingDtos() {}

    /** ACADEMY: a academia paga · TRIAL: teste grátis · SUBSCRIPTION: assinatura ativa · NONE: sem acesso premium. */
    public enum AccessReason { ACADEMY, TRIAL, SUBSCRIPTION, NONE }

    public record SubscriptionStatus(
            boolean premium,
            AccessReason reason,
            Instant expiresAt,
            boolean autoRenewing,
            /** Bloqueio ligado no servidor; desligado, ninguém fica sem acesso. */
            boolean enforced,
            boolean storeConfigured,
            List<String> productIds
    ) {}

    public record GooglePlayPurchaseRequest(
            @NotBlank @Size(max = 100) String productId,
            @NotBlank @Size(max = 512) String purchaseToken
    ) {}

    public record GrantRequest(@Min(1) int days) {}
}
