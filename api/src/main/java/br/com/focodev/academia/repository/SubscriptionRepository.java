package br.com.focodev.academia.repository;

import br.com.focodev.academia.domain.Subscription;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface SubscriptionRepository extends JpaRepository<Subscription, UUID> {
    Optional<Subscription> findByUserId(UUID userId);

    Optional<Subscription> findByPurchaseToken(String purchaseToken);
}
