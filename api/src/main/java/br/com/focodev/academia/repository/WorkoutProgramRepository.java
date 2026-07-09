package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.WorkoutProgram;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutProgramRepository extends JpaRepository<WorkoutProgram, UUID> {

    List<WorkoutProgram> findByInstructorIdOrderByCreatedAtDesc(UUID instructorId);

    @Query("""
            SELECT p FROM WorkoutProgram p
            LEFT JOIN FETCH p.days d
            LEFT JOIN FETCH d.exercises
            WHERE p.id = :id
            """)
    Optional<WorkoutProgram> findByIdWithDays(UUID id);

    @Query("""
            SELECT p FROM WorkoutProgram p
            LEFT JOIN FETCH p.days d
            LEFT JOIN FETCH d.exercises
            WHERE p.student.id = :studentId AND p.active = true
            ORDER BY p.createdAt DESC
            """)
    List<WorkoutProgram> findActiveByStudentId(UUID studentId);

    Optional<WorkoutProgram> findFirstByStudentIdAndActiveTrueOrderByCreatedAtDesc(UUID studentId);
}
