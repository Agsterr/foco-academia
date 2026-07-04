package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.Workout;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutRepository extends JpaRepository<Workout, UUID> {
    List<Workout> findByStudentIdOrderByCreatedAtDesc(UUID studentId);

    List<Workout> findByInstructorIdOrderByCreatedAtDesc(UUID instructorId);

    @Query("SELECT w FROM Workout w LEFT JOIN FETCH w.exercises WHERE w.id = :id")
    Optional<Workout> findByIdWithExercises(UUID id);

    @Query("SELECT w FROM Workout w LEFT JOIN FETCH w.exercises WHERE w.student.id = :studentId ORDER BY w.createdAt DESC")
    List<Workout> findByStudentIdWithExercises(UUID studentId);
}
