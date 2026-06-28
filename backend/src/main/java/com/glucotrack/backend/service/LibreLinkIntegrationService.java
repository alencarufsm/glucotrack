package com.glucotrack.backend.service;

import com.glucotrack.backend.dto.*;
import com.glucotrack.backend.entity.GlucoseReading;
import com.glucotrack.backend.entity.Profile;
import com.glucotrack.backend.enums.MealContext;
import com.glucotrack.backend.enums.ReadingSource;
import com.glucotrack.backend.repository.GlucoseReadingRepository;
import com.glucotrack.backend.repository.ProfileRepository;
import com.glucotrack.backend.service.LibreLinkClientService.LibreGlucoseReading;
import com.glucotrack.backend.service.LibreLinkClientService.LibreLinkSession;
import com.glucotrack.backend.service.LibreLinkClientService.LibrePatient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class LibreLinkIntegrationService {

    private final LibreLinkClientService libreClient;
    private final ProfileRepository profileRepository;
    private final GlucoseReadingRepository readingRepository;
    private final AlertService alertService;

    public LibreLinkTestResponse testCredentials(String email, String password) {
        LibreLinkSession session = libreClient.login(email, password);
        List<LibrePatient> patients = libreClient.getConnections(session);
        List<LibreLinkTestResponse.LibreLinkPatient> result = patients.stream()
                .map(p -> new LibreLinkTestResponse.LibreLinkPatient(p.patientId(), p.displayName()))
                .toList();
        return new LibreLinkTestResponse(result);
    }

    @Transactional
    public void configure(UUID userId, LibreLinkConfigRequest req) {
        Profile profile = findProfile(userId);
        profile.setLibrelinkEmail(req.email());
        profile.setLibrelinkPassword(req.password());
        profile.setLibrelinkPatientId(req.patientId());
        profile.setLibrelinkPatientName(req.patientName());
        profileRepository.save(profile);
    }

    public LibreLinkStatusResponse getStatus(UUID userId) {
        Profile profile = findProfile(userId);
        boolean connected = profile.getLibrelinkEmail() != null;
        return new LibreLinkStatusResponse(
                connected,
                profile.getLibrelinkPatientName(),
                profile.getLibrelinkLastSync()
        );
    }

    @Transactional
    public LibreLinkSyncResponse sync(UUID userId) {
        Profile profile = findProfile(userId);
        if (profile.getLibrelinkEmail() == null) {
            throw new RuntimeException("FreeStyle Libre não configurado");
        }

        LibreLinkSession session = libreClient.login(
                profile.getLibrelinkEmail(),
                profile.getLibrelinkPassword()
        );

        List<LibreGlucoseReading> readings =
                libreClient.getReadings(session, profile.getLibrelinkPatientId());

        // Filtra apenas leituras mais novas que a última já salva — evita duplicatas
        UUID profileId = java.util.Objects.requireNonNull(profile.getId(), "profileId");
        var lastSaved = readingRepository.findLatestTimestampByUserIdAndSource(
                profileId, ReadingSource.LIBRE);
        List<LibreGlucoseReading> newReadings = readings.stream()
                .filter(r -> lastSaved.isEmpty() || r.timestamp().isAfter(lastSaved.get()))
                .toList();

        int saved = 0;
        for (LibreGlucoseReading r : newReadings) {
            GlucoseReading reading = new GlucoseReading();
            reading.setUser(profile);
            reading.setValue(r.valueInMgDl());
            reading.setMeasuredAt(r.timestamp());
            reading.setMealContext(MealContext.OTHER);
            reading.setSource(ReadingSource.LIBRE);
            readingRepository.save(reading);
            alertService.evaluateReading(reading, profile);
            saved++;
        }

        profile.setLibrelinkLastSync(OffsetDateTime.now());
        profileRepository.save(profile);

        log.info("Sync LibreLink — usuário {} — {} leituras salvas", userId, saved);
        return new LibreLinkSyncResponse(saved);
    }

    @Transactional
    public void disconnect(UUID userId) {
        Profile profile = findProfile(userId);
        profile.setLibrelinkEmail(null);
        profile.setLibrelinkPassword(null);
        profile.setLibrelinkPatientId(null);
        profile.setLibrelinkPatientName(null);
        profile.setLibrelinkLastSync(null);
        profileRepository.save(profile);
    }

    private Profile findProfile(UUID userId) {
        return profileRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("Perfil não encontrado"));
    }
}
