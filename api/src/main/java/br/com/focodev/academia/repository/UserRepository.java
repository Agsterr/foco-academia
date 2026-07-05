package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.User;
import br.com.focodev.academia.domain.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmailIgnoreCase(String email);
    boolean existsByEmailIgnoreCase(String email);
    boolean existsByRole(UserRole role);
    List<User> findByRoleAndActiveTrueOrderByNameAsc(UserRole role);
    List<User> findByInstructorIdAndRoleAndActiveTrueOrderByNameAsc(UUID instructorId, UserRole role);
    List<User> findByAcademyIdOrderByNameAsc(UUID academyId);
    long countByAcademyIdAndRole(UUID academyId, UserRole role);
}
