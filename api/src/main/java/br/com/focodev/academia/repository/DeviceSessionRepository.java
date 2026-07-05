package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.DeviceSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeviceSessionRepository extends JpaRepository<DeviceSession, UUID> {
    List<DeviceSession> findByUserIdOrderByLastSeenAtDesc(UUID userId);
    Optional<DeviceSession> findByUserIdAndDeviceId(UUID userId, String deviceId);
    long countByUserId(UUID userId);
    void deleteByUserIdAndDeviceId(UUID userId, String deviceId);
}
