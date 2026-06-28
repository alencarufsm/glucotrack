package com.glucotrack.backend.controller;

import com.glucotrack.backend.dto.*;
import com.glucotrack.backend.service.LibreLinkIntegrationService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/integrations/librelink")
@RequiredArgsConstructor
public class LibreLinkController {

    private final LibreLinkIntegrationService service;

    @GetMapping("/status")
    public ResponseEntity<LibreLinkStatusResponse> status(Authentication auth) {
        return ResponseEntity.ok(service.getStatus(userId(auth)));
    }

    @PostMapping("/test")
    public ResponseEntity<LibreLinkTestResponse> test(
            @Valid @RequestBody LibreLinkTestRequest req) {
        return ResponseEntity.ok(service.testCredentials(req.email(), req.password()));
    }

    @PostMapping("/configure")
    public ResponseEntity<LibreLinkStatusResponse> configure(
            @Valid @RequestBody LibreLinkConfigRequest req,
            Authentication auth) {
        service.configure(userId(auth), req);
        return ResponseEntity.ok(service.getStatus(userId(auth)));
    }

    @PostMapping("/sync")
    public ResponseEntity<LibreLinkSyncResponse> sync(Authentication auth) {
        return ResponseEntity.ok(service.sync(userId(auth)));
    }

    @DeleteMapping
    public ResponseEntity<Void> disconnect(Authentication auth) {
        service.disconnect(userId(auth));
        return ResponseEntity.noContent().build();
    }

    private UUID userId(Authentication auth) {
        return (UUID) auth.getPrincipal();
    }
}
