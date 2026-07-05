package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.Academy;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AcademyRepository extends JpaRepository<Academy, UUID> {
    List<Academy> findAllByOrderByNameAsc();
    long countByActiveTrue();
    Optional<Academy> findBySlugIgnoreCase(String slug);
    boolean existsBySlugIgnoreCase(String slug);
}
