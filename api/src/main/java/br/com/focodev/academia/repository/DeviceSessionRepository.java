package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.AppClientType;
import br.com.focodev.academia.domain.DeviceSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeviceSessionRepository extends JpaRepository<DeviceSession, UUID> {
    List<DeviceSession> findByUserIdOrderByLastSeenAtDesc(UUID userId);
    Optional<DeviceSession> findByUserIdAndDeviceId(UUID userId, String deviceId);
    Optional<DeviceSession> findByUserIdAndDeviceLabel(UUID userId, String deviceLabel);
    long countByUserId(UUID userId);
    void deleteByUserIdAndDeviceId(UUID userId, String deviceId);

    @Query("SELECT s FROM DeviceSession s JOIN FETCH s.user WHERE s.appClient = :appClient ORDER BY s.lastSeenAt DESC")
    List<DeviceSession> findByAppClientWithUser(@Param("appClient") AppClientType appClient);
}
