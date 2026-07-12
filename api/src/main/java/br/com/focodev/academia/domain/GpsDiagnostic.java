package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "gps_diagnostics")
@Getter
@Setter
@NoArgsConstructor
public class GpsDiagnostic {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "session_id")
    private CardioSession session;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "student_id", nullable = false)
    private User student;

    @Column(nullable = false)
    private Instant recordedAt;

    @Column(nullable = false, length = 64)
    private String eventType;

    @Column(length = 500)
    private String message;

    private Double latitude;
    private Double longitude;
    private Double accuracy;
}
