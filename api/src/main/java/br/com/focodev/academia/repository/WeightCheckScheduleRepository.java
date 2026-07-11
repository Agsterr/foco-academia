package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.WeightCheckSchedule;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WeightCheckScheduleRepository extends JpaRepository<WeightCheckSchedule, UUID> {
    Optional<WeightCheckSchedule> findFirstByStudentIdAndCompletedFalseOrderByDueDateAsc(UUID studentId);

    List<WeightCheckSchedule> findByStudentIdOrderByDueDateDesc(UUID studentId);
}
