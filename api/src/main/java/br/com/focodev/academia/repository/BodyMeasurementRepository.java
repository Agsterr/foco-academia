package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.BodyMeasurement;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface BodyMeasurementRepository extends JpaRepository<BodyMeasurement, UUID> {
    List<BodyMeasurement> findByStudentIdOrderByRecordedAtDesc(UUID studentId);
}
