package com.glucotrack.backend.controller;

import com.glucotrack.backend.entity.FamilyConnection;
import com.glucotrack.backend.entity.Profile;
import com.glucotrack.backend.enums.ConnectionStatus;
import com.glucotrack.backend.repository.FamilyConnectionRepository;
import com.glucotrack.backend.repository.ProfileRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/family")
@RequiredArgsConstructor
public class FamilyController {

    private final FamilyConnectionRepository connectionRepository;
    private final ProfileRepository profileRepository;

    // POST /api/family/invite — convida um familiar pelo ID do observador
    @PostMapping("/invite")
    public ResponseEntity<?> invite(
            @RequestBody Map<String, String> body,
            Authentication auth) {

        UUID monitoredId = (UUID) auth.getPrincipal();
        UUID observerId = UUID.fromString(body.get("observerUserId"));

        if (monitoredId.equals(observerId)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Você não pode se convidar."));
        }

        if (connectionRepository.findByMonitoredUserIdAndObserverUserId(monitoredId, observerId).isPresent()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Convite já existente."));
        }

        Profile monitored = profileRepository.findById(monitoredId)
                .orElseThrow(() -> new RuntimeException("Perfil não encontrado"));
        Profile observer = profileRepository.findById(observerId)
                .orElseThrow(() -> new RuntimeException("Familiar não encontrado"));

        FamilyConnection connection = new FamilyConnection();
        connection.setMonitoredUser(monitored);
        connection.setObserverUser(observer);
        connection.setStatus(ConnectionStatus.PENDING);

        return ResponseEntity.ok(connectionRepository.save(connection));
    }

    // PUT /api/family/invite/{id}/accept — familiar aceita o convite
    @PutMapping("/invite/{id}/accept")
    public ResponseEntity<?> accept(@PathVariable UUID id, Authentication auth) {
        UUID observerId = (UUID) auth.getPrincipal();

        FamilyConnection connection = connectionRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Convite não encontrado"));

        if (!connection.getObserverUser().getId().equals(observerId)) {
            return ResponseEntity.status(403).body(Map.of("error", "Sem permissão para aceitar este convite."));
        }

        connection.setStatus(ConnectionStatus.ACTIVE);
        connection.setAcceptedAt(OffsetDateTime.now());
        return ResponseEntity.ok(connectionRepository.save(connection));
    }

    // GET /api/family/connections — lista todas as conexões do usuário
    @GetMapping("/connections")
    public ResponseEntity<List<FamilyConnection>> listConnections(Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        List<FamilyConnection> asObserver = connectionRepository
                .findByObserverUserIdAndStatus(userId, ConnectionStatus.ACTIVE);
        List<FamilyConnection> asMonitored = connectionRepository
                .findByMonitoredUserIdAndStatus(userId, ConnectionStatus.ACTIVE);
        asMonitored.addAll(asObserver);
        return ResponseEntity.ok(asMonitored);
    }
}
