package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.Invite;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface InviteRepository extends JpaRepository<Invite, UUID> {

    @Query("SELECT i FROM Invite i JOIN FETCH i.academy LEFT JOIN FETCH i.instructor WHERE i.code = :code")
    Optional<Invite> findByCode(@Param("code") String code);

    /** Trava o convite enquanto ele é aceito: dois aparelhos abrindo o mesmo link não criam duas contas. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM Invite i WHERE i.code = :code")
    Optional<Invite> lockByCode(@Param("code") String code);

    boolean existsByCode(String code);

    @Query("""
            SELECT i FROM Invite i LEFT JOIN FETCH i.instructor
            WHERE i.academy.id = :academyId AND i.usedAt IS NULL AND (i.revoked IS NULL OR i.revoked = false)
              AND i.expiresAt > :now
            ORDER BY i.createdAt DESC
            """)
    List<Invite> findOpenByAcademy(@Param("academyId") UUID academyId, @Param("now") Instant now);
}
