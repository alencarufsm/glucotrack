package com.glucotrack.backend.controller;

import com.glucotrack.backend.dto.ProfileUpdateRequest;
import com.glucotrack.backend.entity.Profile;
import com.glucotrack.backend.repository.ProfileRepository;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class ProfileController {

    private final ProfileRepository profileRepository;

    // GET /api/users/me — retorna o perfil do usuário logado
    @GetMapping("/me")
    public ResponseEntity<Profile> getMe(Authentication auth) {
        UUID userId = (UUID) auth.getPrincipal();
        return profileRepository.findById(userId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    // PUT /api/users/me — atualiza nome, tipo de diabetes, limitações, faixas-alvo
    @PutMapping("/me")
    public ResponseEntity<Profile> updateMe(
            @Valid @RequestBody ProfileUpdateRequest req,
            Authentication auth) {

        UUID userId = (UUID) auth.getPrincipal();
        Profile profile = profileRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Perfil não encontrado"));

        if (req.name() != null)                profile.setName(req.name());
        if (req.birthDate() != null)            profile.setBirthDate(req.birthDate());
        if (req.diabetesType() != null)         profile.setDiabetesType(req.diabetesType());
        if (req.physicalLimitations() != null)  profile.setPhysicalLimitations(req.physicalLimitations());
        if (req.targetMin() != null)            profile.setTargetMin(req.targetMin());
        if (req.targetMax() != null)            profile.setTargetMax(req.targetMax());

        return ResponseEntity.ok(profileRepository.save(profile));
    }
}
