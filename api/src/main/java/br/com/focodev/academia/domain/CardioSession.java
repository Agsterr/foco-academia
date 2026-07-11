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
@Table(name = "cardio_sessions")
@Getter
@Setter
@NoArgsConstructor
public class CardioSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_id")
    private CardioWorkout workout;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    @Column(nullable = false)
    private Instant startedAt = Instant.now();

    private Instant completedAt;

    private Double distanceMeters;

    private Double avgSpeedKmh;

    private Long elapsedMs;

    private String clientSessionId;

    private boolean synced = true;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sequenceNum ASC")
    private List<RoutePoint> routePoints = new ArrayList<>();
}
