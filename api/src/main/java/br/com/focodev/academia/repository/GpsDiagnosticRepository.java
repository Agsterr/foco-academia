package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.GpsDiagnostic;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.UUID;

public interface GpsDiagnosticRepository extends JpaRepository<GpsDiagnostic, UUID> {

    List<GpsDiagnostic> findBySessionIdOrderByRecordedAtAsc(UUID sessionId);

    @Query("""
            SELECT d.eventType, COUNT(d) FROM GpsDiagnostic d
            JOIN d.student s
            WHERE s.instructor.id = :instructorId
            GROUP BY d.eventType
            """)
    List<Object[]> countByEventTypeForInstructor(UUID instructorId);

    long countBySessionId(UUID sessionId);
}
