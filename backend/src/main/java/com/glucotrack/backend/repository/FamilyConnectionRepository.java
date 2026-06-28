package com.glucotrack.backend.repository;

import com.glucotrack.backend.entity.FamilyConnection;
import com.glucotrack.backend.enums.ConnectionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FamilyConnectionRepository extends JpaRepository<FamilyConnection, UUID> {

    // Retorna todas as conexões ativas onde o usuário é observador
    List<FamilyConnection> findByObserverUserIdAndStatus(UUID observerId, ConnectionStatus status);

    // Retorna todas as conexões ativas onde o usuário é monitorado
    List<FamilyConnection> findByMonitoredUserIdAndStatus(UUID monitoredId, ConnectionStatus status);

    // Verifica se já existe conexão entre dois usuários
    Optional<FamilyConnection> findByMonitoredUserIdAndObserverUserId(UUID monitoredId, UUID observerId);

    // Lista todos os observadores ativos de um usuário monitorado (para enviar alertas)
    List<FamilyConnection> findByMonitoredUserIdAndStatusOrderByInvitedAtDesc(
            UUID monitoredId, ConnectionStatus status);
}
