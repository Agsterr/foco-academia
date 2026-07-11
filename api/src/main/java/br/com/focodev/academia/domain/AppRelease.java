package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_releases")
@Getter
@Setter
@NoArgsConstructor
public class AppRelease {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false, length = 32)
    private String versionName;

    @Column(nullable = false, unique = true)
    private int versionCode;

    @Column(nullable = false)
    private String fileName;

    @Column(nullable = false)
    private long fileSizeBytes;

    @Column(nullable = false, length = 64)
    private String sha256;

    private String releaseNotes;

    @Column(nullable = false)
    private boolean forceUpdate;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false, updatable = false)
    private Instant createdAt = Instant.now();
}
