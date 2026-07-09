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

    @Query("""
            SELECT DISTINCT w FROM Workout w
            LEFT JOIN FETCH w.exercises
            LEFT JOIN FETCH w.student s
            LEFT JOIN FETCH s.academy
            LEFT JOIN FETCH s.instructor
            WHERE w.id = :id
            """)
    Optional<Workout> findByIdWithExercises(UUID id);

    @Query("""
            SELECT DISTINCT w FROM Workout w
            LEFT JOIN FETCH w.exercises
            LEFT JOIN FETCH w.student s
            LEFT JOIN FETCH s.academy
            LEFT JOIN FETCH s.instructor
            WHERE w.student.id = :studentId
            ORDER BY w.createdAt DESC
            """)
    List<Workout> findByStudentIdWithExercises(UUID studentId);

    @Query("""
            SELECT DISTINCT w FROM Workout w
            LEFT JOIN FETCH w.exercises
            LEFT JOIN FETCH w.student s
            LEFT JOIN FETCH s.academy
            LEFT JOIN FETCH s.instructor
            WHERE w.instructor.id = :instructorId
            ORDER BY w.createdAt DESC
            """)
    List<Workout> findByInstructorIdWithDetails(UUID instructorId);
}
