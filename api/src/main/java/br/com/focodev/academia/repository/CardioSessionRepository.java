package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.CardioSession;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CardioSessionRepository extends JpaRepository<CardioSession, UUID> {
    List<CardioSession> findByStudentIdOrderByStartedAtDesc(UUID studentId);

    @Query("SELECT s FROM CardioSession s JOIN s.student st WHERE st.instructor.id = :instructorId ORDER BY s.startedAt DESC")
    List<CardioSession> findByInstructorStudents(UUID instructorId);

    Optional<CardioSession> findByStudentIdAndCompletedAtIsNull(UUID studentId);

    Optional<CardioSession> findByClientSessionId(String clientSessionId);

    long countByStudentIdAndCompletedAtAfter(UUID studentId, Instant after);

    List<CardioSession> findByWorkoutId(UUID workoutId);
}
