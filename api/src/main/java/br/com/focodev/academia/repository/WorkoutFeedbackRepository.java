package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.WorkoutFeedback;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutFeedbackRepository extends JpaRepository<WorkoutFeedback, UUID> {
    List<WorkoutFeedback> findByWorkoutIdOrderByCreatedAtDesc(UUID workoutId);
    List<WorkoutFeedback> findByWorkoutInstructorIdOrderByCreatedAtDesc(UUID instructorId);
    Optional<WorkoutFeedback> findByWorkoutIdAndStudentId(UUID workoutId, UUID studentId);
}
