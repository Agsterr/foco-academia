package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/** Acesso premium do aluno avulso: teste grátis, assinatura do Google Play ou liberado pelo admin. */
@Entity
@Table(name = "subscriptions")
@Getter
@Setter
@NoArgsConstructor
public class Subscription {

    public enum Source { TRIAL, GOOGLE_PLAY, ADMIN }

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", unique = true)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Source source;

    /** Acesso vale até este instante (renovações do Google estendem). */
    @Column(nullable = false)
    private Instant expiresAt;

    @Column(length = 100)
    private String productId;

    @Column(length = 512)
    private String purchaseToken;

    private Boolean autoRenewing;

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    public boolean isActive(Instant now) {
        return expiresAt != null && expiresAt.isAfter(now);
    }
}
