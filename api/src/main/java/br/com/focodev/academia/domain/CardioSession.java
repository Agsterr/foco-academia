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

    /** Tempo total parado (pausa manual + auto-pause), em ms. */
    private Long pausedMs = 0L;

    /** Quantas vezes entrou em pausa nesta sessão. */
    private Integer pauseCount = 0;

    /** Estimativa MET (kcal). */
    private Integer caloriesKcal;

    /** Qualidade GPS 0–100 (calculada no app). */
    private Double gpsQualityScore;

    /** Rótulo: Excelente / Boa / Razoável / Baixa precisão */
    private String gpsQualityLabel;

    private String gpsAlgorithmVersion;
    private String filterVersion;
    private String kalmanVersion;
    private String distanceVersion;
    private String caloriesVersion;

    /** Snapshot JSON das flags GpsConfig usadas na corrida. */
    @Column(length = 2000)
    private String gpsConfigSnapshot;

    private String clientSessionId;

    private boolean synced = true;

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sequenceNum ASC")
    private List<RoutePoint> routePoints = new ArrayList<>();

    @OneToMany(mappedBy = "session", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("recordedAt ASC")
    private java.util.List<br.com.focodev.academia.domain.GpsDiagnostic> diagnostics = new ArrayList<>();
}
