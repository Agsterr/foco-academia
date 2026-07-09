package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.SetLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SetLogRepository extends JpaRepository<SetLog, UUID> {

    List<SetLog> findBySessionIdOrderByCompletedAtAsc(UUID sessionId);

    Optional<SetLog> findBySessionIdAndExerciseIdAndSetNumber(UUID sessionId, UUID exerciseId, int setNumber);
}
