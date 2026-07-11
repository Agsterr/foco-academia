package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.CardioWorkout;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CardioWorkoutRepository extends JpaRepository<CardioWorkout, UUID> {
    List<CardioWorkout> findByStudentIdAndActiveTrueOrderByCreatedAtDesc(UUID studentId);

    List<CardioWorkout> findByInstructorIdOrderByCreatedAtDesc(UUID instructorId);

    Optional<CardioWorkout> findFirstByStudentIdAndActiveTrueOrderByCreatedAtDesc(UUID studentId);
}
