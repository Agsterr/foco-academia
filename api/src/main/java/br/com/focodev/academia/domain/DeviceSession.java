package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "device_sessions", uniqueConstraints = {
        @UniqueConstraint(columnNames = {"user_id", "device_id"})
})
@Getter
@Setter
@NoArgsConstructor
public class DeviceSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    private String deviceLabel;

    @Column(nullable = false)
    private Instant lastSeenAt = Instant.now();

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
