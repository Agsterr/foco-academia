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
@Table(name = "workout_sessions")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_day_id")
    private WorkoutDay workoutDay;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private User student;

    @Column(nullable = false, updatable = false)
    private Instant startedAt = Instant.now();

    private Instant completedAt;

    private Long totalDurationSeconds;

    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private RatingLevel rating;

    @Column(length = 1000)
    private String comment;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<SetLog> setLogs = new ArrayList<>();
}
