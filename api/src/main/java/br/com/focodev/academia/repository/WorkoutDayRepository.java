package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.WorkoutDay;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.Optional;
import java.util.UUID;

public interface WorkoutDayRepository extends JpaRepository<WorkoutDay, UUID> {

    @Query("""
            SELECT d FROM WorkoutDay d
            JOIN FETCH d.program p
            LEFT JOIN FETCH d.exercises
            WHERE d.id = :id
            """)
    Optional<WorkoutDay> findByIdWithDetails(UUID id);
}
