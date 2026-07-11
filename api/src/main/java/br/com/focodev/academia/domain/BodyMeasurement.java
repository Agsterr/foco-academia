package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "body_measurements")
@Getter
@Setter
@NoArgsConstructor
public class BodyMeasurement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    private Double weightKg;

    private Double waistCm;

    private Double hipsCm;

    private Double chestCm;

    @Column(nullable = false)
    private Instant recordedAt = Instant.now();

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private MeasurementSource source = MeasurementSource.STUDENT;

    private String notes;
}
