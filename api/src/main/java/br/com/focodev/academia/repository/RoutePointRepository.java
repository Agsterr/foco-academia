package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.RoutePoint;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface RoutePointRepository extends JpaRepository<RoutePoint, UUID> {
    void deleteBySessionId(UUID sessionId);
}
