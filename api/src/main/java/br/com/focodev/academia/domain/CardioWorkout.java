package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "cardio_workouts")
@Getter
@Setter
@NoArgsConstructor
public class CardioWorkout {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    /** Nulo quando o aluno iniciou o treino a partir de um treino pronto. */
    @JoinColumn(name = "instructor_id")
    private User instructor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    @Column(nullable = false)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private CardioType type;

    @Column(columnDefinition = "TEXT")
    private String intervalsJson;

    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
