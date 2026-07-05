package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "academies")
@Getter
@Setter
@NoArgsConstructor
public class Academy {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String name;

    /** Identificador único da academia (multi-tenant). Usado no login. */
    @Column(nullable = false, unique = true, length = 64)
    private String slug;

    /** Máximo de dispositivos simultâneos por usuário (aluno/instrutor). */
    @Column(nullable = false)
    private int deviceLimitPerUser = 3;

    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
