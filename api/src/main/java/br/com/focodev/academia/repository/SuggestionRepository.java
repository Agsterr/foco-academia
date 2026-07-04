package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.Suggestion;
import br.com.focodev.academia.domain.SuggestionStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SuggestionRepository extends JpaRepository<Suggestion, UUID> {
    List<Suggestion> findByStudentIdOrderByCreatedAtDesc(UUID studentId);
    List<Suggestion> findByInstructorIdOrderByCreatedAtDesc(UUID instructorId);
    long countByInstructorIdAndStatus(UUID instructorId, SuggestionStatus status);
}
