package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.AppRelease;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppReleaseRepository extends JpaRepository<AppRelease, UUID> {
    Optional<AppRelease> findFirstByActiveTrueOrderByVersionCodeDescCreatedAtDesc();

    List<AppRelease> findByActiveTrueOrderByVersionCodeDescCreatedAtDesc();

    List<AppRelease> findAllByOrderByVersionCodeDescCreatedAtDesc();

    boolean existsByVersionCode(int versionCode);
}
