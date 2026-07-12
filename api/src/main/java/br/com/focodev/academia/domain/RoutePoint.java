package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "route_points")
@Getter
@Setter
@NoArgsConstructor
public class RoutePoint {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id", nullable = false)
    private CardioSession session;

    @Column(nullable = false)
    private double latitude;

    @Column(nullable = false)
    private double longitude;

    /** Velocidade em km/h (quando disponível). */
    private Double speedKmh;

    /** Precisão horizontal em metros. */
    private Double accuracyMeters;

    /** Direção do deslocamento em graus (0–360). */
    private Double heading;

    /** Altitude em metros. */
    private Double altitudeMeters;

    /** Origem do fix: gps, fused, network, etc. */
    private String provider;

    /** true se o cliente marcou o ponto como filtrado/rejeitado. */
    @Column(name = "is_filtered")
    private Boolean filtered;

    /** Nível de bateria 0–100 no momento do fix (opcional). */
    private Double batteryLevel;

    /** Precisão vertical (iOS / quando disponível). */
    private Double verticalAccuracy;

    /** Precisão do bearing/heading (Android / quando disponível). */
    private Double bearingAccuracy;

    /** Precisão da velocidade (Android / quando disponível). */
    private Double speedAccuracy;

    /** Motivo do filtro (NONE, LOW_ACCURACY, ...). */
    private String filterReason;

    /** Confiança 0–1. */
    private Double confidenceScore;

    @Column(nullable = false)
    private Instant recordedAt;

    @Column(nullable = false)
    private int sequenceNum;
}
