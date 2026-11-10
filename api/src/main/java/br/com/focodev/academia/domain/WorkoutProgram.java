package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "workout_programs")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutProgram {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String title;

    @Column(length = 2000)
    private String description;

    /** Nulo quando o próprio aluno criou a ficha (ou a iniciou de um treino pronto). */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "instructor_id")
    private User instructor;

    /** Chave do treino pronto de origem (ex.: "musculacao-iniciante"), quando houver. */
    @Column(length = 80)
    private String templateKey;

    /** Ficha do aluno apagada/substituída: some da lista, mas o histórico de treinos continua. */
    private Boolean archived;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private User student;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    @OneToMany(mappedBy = "program", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<WorkoutDay> days = new ArrayList<>();

    public boolean isOwnedByStudent() {
        return instructor == null;
    }

    public boolean isArchived() {
        return Boolean.TRUE.equals(archived);
    }
}
