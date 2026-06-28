package com.glucotrack.backend.controller;

import com.glucotrack.backend.entity.Alert;
import com.glucotrack.backend.service.AlertService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/alerts")
@RequiredArgsConstructor
public class AlertController {

    private final AlertService alertService;

    // GET /api/alerts — todos os alertas do usuário
    @GetMapping
    public ResponseEntity<List<Alert>> list(Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        return ResponseEntity.ok(alertService.getAlertsForUser(userId));
    }

    // GET /api/alerts/unread — alertas não lidos (inclui os de quem o usuário observa)
    @GetMapping("/unread")
    public ResponseEntity<List<Alert>> unread(Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        return ResponseEntity.ok(alertService.getUnreadAlerts(userId));
    }
}
