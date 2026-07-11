package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.WorkoutSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, UUID> {

    @Query("""
            SELECT s FROM WorkoutSession s
            LEFT JOIN FETCH s.setLogs
            WHERE s.id = :id
            """)
    Optional<WorkoutSession> findByIdWithSetLogs(UUID id);

    Optional<WorkoutSession> findByWorkoutDayIdAndStudentIdAndCompletedAtIsNull(UUID workoutDayId, UUID studentId);

    @Query("""
            SELECT s FROM WorkoutSession s
            WHERE s.student.id = :studentId
            AND s.completedAt IS NOT NULL
            AND s.completedAt >= :since
            """)
    List<WorkoutSession> findCompletedSince(UUID studentId, Instant since);

    long countByStudentIdAndCompletedAtIsNotNull(UUID studentId);

    @Query("""
            SELECT s FROM WorkoutSession s
            WHERE s.student.id = :studentId
            AND s.completedAt IS NOT NULL
            ORDER BY s.completedAt DESC
            """)
    List<WorkoutSession> findCompletedByStudentId(UUID studentId);

    @Query("""
            SELECT s FROM WorkoutSession s
            JOIN FETCH s.workoutDay d
            JOIN FETCH d.program p
            JOIN FETCH s.student st
            WHERE p.instructor.id = :instructorId
            AND s.completedAt IS NOT NULL
            ORDER BY s.completedAt DESC
            """)
    List<WorkoutSession> findCompletedByInstructorId(UUID instructorId);
}
