package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

/** Convite de uso único: a academia convida instrutores e o instrutor convida alunos. */
@Entity
@Table(name = "invites")
@Getter
@Setter
@NoArgsConstructor
public class Invite {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    /** Código curto do link (sem caracteres ambíguos), ex.: K7Q2MX9P3T. */
    @Column(nullable = false, unique = true, length = 16)
    private String code;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "academy_id")
    private Academy academy;

    /** ALUNO ou INSTRUTOR. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private UserRole role;

    /** Instrutor do aluno convidado (nulo em convite de instrutor). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "instructor_id")
    private User instructor;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "created_by_id")
    private User createdBy;

    /** Nome sugerido para o convidado (opcional). */
    private String name;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant expiresAt;

    private Instant usedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "used_by_id")
    private User usedBy;

    private Boolean revoked;

    public boolean isRevoked() {
        return Boolean.TRUE.equals(revoked);
    }

    public boolean isOpen(Instant now) {
        return usedAt == null && !isRevoked() && expiresAt.isAfter(now);
    }
}
