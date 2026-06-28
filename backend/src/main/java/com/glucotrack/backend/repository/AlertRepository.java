package com.glucotrack.backend.repository;

import com.glucotrack.backend.entity.Alert;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface AlertRepository extends JpaRepository<Alert, UUID> {

    List<Alert> findByUserIdOrderByTriggeredAtDesc(UUID userId);

    // Alertas não lidos onde o usuário é o dono OU foi notificado
    // Usa SQL nativo porque JPQL não suporta a sintaxe ANY() para arrays PostgreSQL
    @Query(value = "SELECT * FROM alerts WHERE (user_id = :userId OR :userId::uuid = ANY(notified_users)) AND is_read = false ORDER BY triggered_at DESC", nativeQuery = true)
    List<Alert> findUnreadByUserIdOrNotified(UUID userId);
}
