package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.GoalCheckIn;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface GoalCheckInRepository extends JpaRepository<GoalCheckIn, UUID> {
    List<GoalCheckIn> findByStudentIdOrderByCreatedAtDesc(UUID studentId);
}
