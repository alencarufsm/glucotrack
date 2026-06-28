package com.glucotrack.backend.controller;

import com.glucotrack.backend.dto.GlucoseReadingRequest;
import com.glucotrack.backend.dto.GlucoseReadingResponse;
import com.glucotrack.backend.entity.GlucoseReading;
import com.glucotrack.backend.entity.Profile;
import com.glucotrack.backend.enums.MealContext;
import com.glucotrack.backend.enums.ReadingSource;
import com.glucotrack.backend.repository.GlucoseReadingRepository;
import com.glucotrack.backend.repository.ProfileRepository;
import com.glucotrack.backend.service.AlertService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/readings")
@RequiredArgsConstructor
public class ReadingController {

    private final GlucoseReadingRepository readingRepository;
    private final ProfileRepository profileRepository;
    private final AlertService alertService;

    // POST /api/readings — registra nova medição
    @PostMapping
    public ResponseEntity<GlucoseReadingResponse> create(
            @Valid @RequestBody GlucoseReadingRequest req,
            Authentication auth) {

        UUID userId = (UUID) auth.getPrincipal();
        Profile user = profileRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Perfil não encontrado"));

        GlucoseReading reading = new GlucoseReading();
        reading.setUser(user);
        reading.setValue(req.value());
        reading.setMeasuredAt(req.measuredAt() != null ? req.measuredAt() : OffsetDateTime.now());
        reading.setMealContext(req.mealContext() != null ? req.mealContext() : MealContext.OTHER);
        reading.setSource(req.source() != null ? req.source() : ReadingSource.MANUAL);
        reading.setNotes(req.notes());

        GlucoseReading saved = readingRepository.save(reading);

        // Avalia alerta automaticamente após salvar
        alertService.evaluateReading(saved, user);

        return ResponseEntity.ok(GlucoseReadingResponse.from(saved));
    }

    // GET /api/readings — histórico com filtro opcional de data
    @GetMapping
    public ResponseEntity<List<GlucoseReadingResponse>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            Authentication auth) {

        UUID userId = (UUID) auth.getPrincipal();
        List<GlucoseReading> readings;

        if (from != null && to != null) {
            readings = readingRepository.findByUserIdAndMeasuredAtBetweenOrderByMeasuredAtDesc(userId, from, to);
        } else {
            readings = readingRepository.findByUserIdOrderByMeasuredAtDesc(userId);
        }

        return ResponseEntity.ok(readings.stream().map(GlucoseReadingResponse::from).toList());
    }

    // GET /api/readings/latest — última medição registrada
    @GetMapping("/latest")
    public ResponseEntity<GlucoseReadingResponse> latest(Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        return readingRepository.findFirstByUserIdOrderByMeasuredAtDesc(userId)
                .map(r -> ResponseEntity.ok(GlucoseReadingResponse.from(r)))
                .orElse(ResponseEntity.notFound().build());
    }

    // GET /api/readings/user/{userId} — observador acessa medições de monitorado
    @GetMapping("/user/{targetUserId}")
    public ResponseEntity<List<GlucoseReadingResponse>> listForUser(
            @PathVariable UUID targetUserId,
            Authentication auth) {

        // TODO: verificar se o usuário logado tem conexão ativa como observador do targetUserId
        List<GlucoseReading> readings = readingRepository.findByUserIdOrderByMeasuredAtDesc(targetUserId);
        return ResponseEntity.ok(readings.stream().map(GlucoseReadingResponse::from).toList());
    }
}
