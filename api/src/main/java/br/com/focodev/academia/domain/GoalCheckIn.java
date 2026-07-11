package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "goal_check_ins")
@Getter
@Setter
@NoArgsConstructor
public class GoalCheckIn {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    private boolean achievingGoal;

    @Column(nullable = false)
    private int progressRating;

    private String comment;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
