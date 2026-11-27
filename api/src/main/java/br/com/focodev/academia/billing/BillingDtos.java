package br.com.focodev.academia.billing;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.List;

public final class BillingDtos {

    private BillingDtos() {}

    /** COURTESY: e-mail liberado · TRIAL: teste grátis · SUBSCRIPTION: assinatura ativa · NONE: sem acesso premium. */
    public enum AccessReason { COURTESY, TRIAL, SUBSCRIPTION, NONE }

    public record SubscriptionStatus(
            boolean premium,
            AccessReason reason,
            Instant expiresAt,
            boolean autoRenewing,
            /** Bloqueio ligado no servidor; desligado, ninguém fica sem acesso. */
            boolean enforced,
            boolean storeConfigured,
            List<String> productIds,
            /** Aluno de academia ou personal: preço reduzido e a ficha do instrutor depende da assinatura. */
            boolean academyStudent
    ) {}

    public record GooglePlayPurchaseRequest(
            @NotBlank @Size(max = 100) String productId,
            @NotBlank @Size(max = 512) String purchaseToken
    ) {}

    public record GrantRequest(@Min(1) int days) {}
}
